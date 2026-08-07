import Foundation
import Testing

@testable import StudentKit

// Simulator/device acceptance remains responsible for the one boundary a
// macOS host cannot reproduce: kill the app mid-PUT, relaunch it through
// UIApplicationDelegate, and verify the daemon-restored URLSession callbacks.
@Test func productionUploaderPairsContinuationWithBackgroundEvents() async throws {
  let sessionIdentifier = "production-uploader-\(UUID().uuidString)"
  let taskFactory = FakeBackgroundUploadTaskFactory()
  let uploader = BackgroundVideoPartUploader(
    sessionIdentifier: sessionIdentifier,
    uploadTaskFactory: { request, fileURL in
      taskFactory.makeTask(request: request, fileURL: fileURL)
    }
  )
  let identifier = VideoUploadPartIdentifier(recordID: UUID(), partNumber: 2)
  let upload = Task {
    try await uploader.upload(
      to: try #require(URL(string: "https://oss.test/parts/2")),
      from: URL(fileURLWithPath: "/tmp/fake-part.chunk"),
      identifier: identifier
    )
  }
  try await waitUntil { taskFactory.task?.wasResumed == true }
  let task = try #require(taskFactory.task)
  let handlerCounter = UploaderLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(identifier: sessionIdentifier) {
    handlerCounter.increment()
  }

  uploader.receiveCompletion(
    taskIdentifier: task.taskIdentifier,
    taskDescription: task.taskDescription,
    result: .success("etag-2")
  )
  let delegateSession = URLSession(configuration: .ephemeral)
  uploader.urlSessionDidFinishEvents(forBackgroundURLSession: delegateSession)
  delegateSession.finishTasksAndInvalidate()

  await #expect(throws: BackgroundUploadPipelineDeferred.self) {
    try await upload.value
  }
  let tokens = try await productionEventTokens(
    from: uploader,
    partIdentifier: identifier,
    sessionIdentifier: sessionIdentifier,
    expectedResult: .success("etag-2")
  )

  BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(tokens.part)
  #expect(handlerCounter.value == 0)
  BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(tokens.finish)
  try await waitUntil { handlerCounter.value == 1 }
}

@Test func productionUploaderDefersFailureToRestoredEventOwner() async throws {
  let sessionIdentifier = "failed-uploader-\(UUID().uuidString)"
  let taskFactory = FakeBackgroundUploadTaskFactory()
  let uploader = BackgroundVideoPartUploader(
    sessionIdentifier: sessionIdentifier,
    uploadTaskFactory: { request, fileURL in
      taskFactory.makeTask(request: request, fileURL: fileURL)
    }
  )
  let identifier = VideoUploadPartIdentifier(recordID: UUID(), partNumber: 2)
  let upload = Task {
    try await uploader.upload(
      to: try #require(URL(string: "https://oss.test/parts/2")),
      from: URL(fileURLWithPath: "/tmp/failed-part.chunk"),
      identifier: identifier
    )
  }
  try await waitUntil { taskFactory.task?.wasResumed == true }
  let task = try #require(taskFactory.task)
  let handlerCounter = UploaderLockedCounter()
  BackgroundUploadCompletionRegistry.shared.store(identifier: sessionIdentifier) {
    handlerCounter.increment()
  }

  uploader.receiveCompletion(
    taskIdentifier: task.taskIdentifier,
    taskDescription: task.taskDescription,
    result: .failure(.httpStatus(403))
  )
  let delegateSession = URLSession(configuration: .ephemeral)
  uploader.urlSessionDidFinishEvents(forBackgroundURLSession: delegateSession)
  delegateSession.finishTasksAndInvalidate()

  await #expect(throws: BackgroundUploadPipelineDeferred.self) { try await upload.value }
  let tokens = try await productionEventTokens(
    from: uploader,
    partIdentifier: identifier,
    sessionIdentifier: sessionIdentifier,
    expectedResult: .failure(.httpStatus(403))
  )
  BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(tokens.part)
  #expect(handlerCounter.value == 0)
  BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(tokens.finish)
  try await waitUntil { handlerCounter.value == 1 }
}

@Test func productionUploaderMarksRelaunchedTaskWithoutContinuation() async throws {
  let sessionIdentifier = "restored-uploader-\(UUID().uuidString)"
  let uploader = BackgroundVideoPartUploader(
    sessionIdentifier: sessionIdentifier,
    uploadTaskFactory: { _, _ in FakeBackgroundUploadTask(taskIdentifier: 1) }
  )
  let identifier = VideoUploadPartIdentifier(recordID: UUID(), partNumber: 3)

  uploader.receiveCompletion(
    taskIdentifier: 999,
    taskDescription: identifier.taskDescription,
    result: .failure(.network(.networkConnectionLost))
  )

  var iterator = uploader.events.makeAsyncIterator()
  guard case .part(let event) = await iterator.next() else {
    Issue.record("Expected restored production uploader event")
    return
  }
  #expect(event.identifier == identifier)
  #expect(!event.hasPipelineContinuation)
  #expect(event.result == .failure(.network(.networkConnectionLost)))
  BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(event.completionToken)
}

private func productionEventTokens(
  from uploader: BackgroundVideoPartUploader,
  partIdentifier: VideoUploadPartIdentifier,
  sessionIdentifier: String,
  expectedResult: Result<String, VideoPartUploadFailure>
) async throws -> (part: BackgroundUploadEventToken, finish: BackgroundUploadEventToken) {
  var partToken: BackgroundUploadEventToken?
  var finishToken: BackgroundUploadEventToken?
  var iterator = uploader.events.makeAsyncIterator()
  for _ in 0..<2 {
    switch await iterator.next() {
    case .part(let event):
      #expect(event.identifier == partIdentifier)
      #expect(event.hasPipelineContinuation)
      #expect(event.result == expectedResult)
      partToken = event.completionToken
    case .sessionEventsFinished(let identifier, let completionToken):
      #expect(identifier == sessionIdentifier)
      finishToken = completionToken
    case nil:
      Issue.record("Expected production uploader events")
    }
  }
  return (try #require(partToken), try #require(finishToken))
}

// OSS V1 presigned URLs are signed with an empty Content-Type; CFNetwork
// infers one from the file extension on file-based tasks unless the header
// is explicitly present (2026-08-04 E2E 403 regression).
@Test func partRequestsPinAnEmptyContentTypeOnBothPaths() async throws {
  let taskFactory = FakeBackgroundUploadTaskFactory()
  let uploader = BackgroundVideoPartUploader(
    sessionIdentifier: "content-type-\(UUID().uuidString)",
    uploadTaskFactory: { request, fileURL in
      taskFactory.makeTask(request: request, fileURL: fileURL)
    }
  )

  let uploadTask = Task {
    try await uploader.upload(
      to: try #require(URL(string: "https://oss.test/parts/1")),
      from: URL(fileURLWithPath: "/tmp/content-type-part.chunk"),
      identifier: VideoUploadPartIdentifier(recordID: UUID(), partNumber: 1)
    )
  }
  try await waitUntil { taskFactory.task?.wasResumed == true }
  let awaitedRequest = try #require(taskFactory.request)
  #expect(awaitedRequest.value(forHTTPHeaderField: "Content-Type") == "")
  uploader.receiveCompletion(
    taskIdentifier: try #require(taskFactory.task).taskIdentifier,
    taskDescription: taskFactory.task?.taskDescription,
    result: .success("etag-1")
  )
  _ = try? await uploadTask.value

  let scheduledFile = FileManager.default.temporaryDirectory
    .appending(path: "content-type-scheduled-\(UUID().uuidString).chunk")
  try Data("part".utf8).write(to: scheduledFile)
  defer { try? FileManager.default.removeItem(at: scheduledFile) }
  try uploader.schedule(
    to: try #require(URL(string: "https://oss.test/parts/2")),
    from: scheduledFile,
    identifier: VideoUploadPartIdentifier(recordID: UUID(), partNumber: 2)
  )
  let scheduledRequest = try #require(taskFactory.request)
  #expect(scheduledRequest.value(forHTTPHeaderField: "Content-Type") == "")
}

private final class FakeBackgroundUploadTaskFactory: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: FakeBackgroundUploadTask?
  private var requestStorage: URLRequest?

  var task: FakeBackgroundUploadTask? { lock.withLock { storage } }
  var request: URLRequest? { lock.withLock { requestStorage } }

  func makeTask(request: URLRequest, fileURL: URL) -> FakeBackgroundUploadTask {
    let task = FakeBackgroundUploadTask(taskIdentifier: 42)
    lock.withLock {
      storage = task
      requestStorage = request
    }
    return task
  }
}

private final class FakeBackgroundUploadTask: BackgroundUploadTask, @unchecked Sendable {
  let taskIdentifier: Int
  private let lock = NSLock()
  private var descriptionStorage: String?
  private var resumedStorage = false

  var taskDescription: String? {
    get { lock.withLock { descriptionStorage } }
    set { lock.withLock { descriptionStorage = newValue } }
  }

  var wasResumed: Bool { lock.withLock { resumedStorage } }

  init(taskIdentifier: Int) {
    self.taskIdentifier = taskIdentifier
  }

  func resume() {
    lock.withLock { resumedStorage = true }
  }
}

private final class UploaderLockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0

  var value: Int { lock.withLock { storage } }

  func increment() {
    lock.withLock { storage += 1 }
  }
}
