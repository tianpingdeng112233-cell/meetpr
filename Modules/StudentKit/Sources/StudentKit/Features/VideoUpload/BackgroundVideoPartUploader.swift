import Foundation

public struct VideoUploadPartIdentifier: Hashable, Sendable {
  public let recordID: UUID
  public let partNumber: Int

  var taskDescription: String {
    "\(recordID.uuidString)|\(partNumber)"
  }

  public init(recordID: UUID, partNumber: Int) {
    self.recordID = recordID
    self.partNumber = partNumber
  }

  init?(taskDescription: String?) {
    guard let taskDescription else { return nil }
    let pieces = taskDescription.split(separator: "|", omittingEmptySubsequences: false)
    guard pieces.count == 2,
      let recordID = UUID(uuidString: String(pieces[0])),
      let partNumber = Int(pieces[1])
    else { return nil }
    self.init(recordID: recordID, partNumber: partNumber)
  }
}

public enum VideoPartUploadFailure: Error, Equatable, Sendable {
  case cancelled
  case httpStatus(Int)
  case missingETag
  case network(URLError.Code)
  case invalidResponse
  case unknown
}

struct BackgroundUploadPipelineDeferred: Error, Equatable, Sendable {}

public struct BackgroundVideoPartEvent: Sendable {
  public let identifier: VideoUploadPartIdentifier
  public let result: Result<String, VideoPartUploadFailure>
  public let completionToken: BackgroundUploadEventToken
  /// False for tasks restored after process death. True means this callback
  /// was paired with an in-process `uploadPart` continuation; during an OS
  /// wake that continuation is deferred so the bounded recovery path owns
  /// ETag persistence and next-batch scheduling.
  public let hasPipelineContinuation: Bool

  public init(
    identifier: VideoUploadPartIdentifier,
    result: Result<String, VideoPartUploadFailure>,
    completionToken: BackgroundUploadEventToken = BackgroundUploadEventToken(
      sessionIdentifier: "com.meetpr.app.video-upload"
    ),
    hasPipelineContinuation: Bool = false
  ) {
    self.identifier = identifier
    self.result = result
    self.completionToken = completionToken
    self.hasPipelineContinuation = hasPipelineContinuation
  }
}

public enum BackgroundVideoUploadEvent: Sendable {
  case part(BackgroundVideoPartEvent)
  case sessionEventsFinished(identifier: String, completionToken: BackgroundUploadEventToken)
}

protocol BackgroundUploadTask: AnyObject {
  var taskIdentifier: Int { get }
  var taskDescription: String? { get set }
  func resume()
}

extension URLSessionUploadTask: BackgroundUploadTask {}

final class BackgroundVideoPartUploader: NSObject, @unchecked Sendable {
  static let sessionIdentifier = "com.meetpr.app.video-upload"

  let events: AsyncStream<BackgroundVideoUploadEvent>

  private let eventContinuation: AsyncStream<BackgroundVideoUploadEvent>.Continuation
  private let lock = NSLock()
  private var continuations: [Int: CheckedContinuation<String, any Error>] = [:]
  private var sessionStorage: URLSession?
  private let sessionIdentifier: String
  private let uploadTaskFactory: ((URLRequest, URL) -> any BackgroundUploadTask)?
  private var session: URLSession {
    lock.withLock {
      if let sessionStorage { return sessionStorage }
      let session = makeSession()
      sessionStorage = session
      return session
    }
  }

  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
    configuration.waitsForConnectivity = true
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = false
    configuration.httpMaximumConnectionsPerHost = 3
    return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }

  init(
    sessionIdentifier: String = BackgroundVideoPartUploader.sessionIdentifier,
    uploadTaskFactory: ((URLRequest, URL) -> any BackgroundUploadTask)? = nil
  ) {
    self.sessionIdentifier = sessionIdentifier
    self.uploadTaskFactory = uploadTaskFactory
    let stream = AsyncStream.makeStream(
      of: BackgroundVideoUploadEvent.self,
      bufferingPolicy: .bufferingNewest(128)
    )
    events = stream.stream
    eventContinuation = stream.continuation
    super.init()
    BackgroundUploadSessionLifecycle.shared.register(identifier: sessionIdentifier) { [weak self] in
      self?.reconnectSession()
    }
  }

  deinit {
    eventContinuation.finish()
  }

  func upload(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws -> String {
    let task = makeUploadTask(request: Self.makePartRequest(url: url), fileURL: fileURL)
    task.taskDescription = identifier.taskDescription
    return try await withCheckedThrowingContinuation { continuation in
      lock.withLock {
        continuations[task.taskIdentifier] = continuation
      }
      task.resume()
    }
  }

  func schedule(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) throws {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw VideoUploadError.localFileMissing
    }
    let task = makeUploadTask(request: Self.makePartRequest(url: url), fileURL: fileURL)
    task.taskDescription = identifier.taskDescription
    task.resume()
  }

  func pendingParts(recordID: UUID) async -> Set<Int> {
    let tasks = await session.allTasks
    return Set(
      tasks.compactMap { task in
        guard let identifier = VideoUploadPartIdentifier(taskDescription: task.taskDescription),
          identifier.recordID == recordID
        else { return nil }
        return identifier.partNumber
      }
    )
  }

  func cancelParts(recordID: UUID) async {
    let tasks = await session.allTasks
    for task in tasks {
      guard VideoUploadPartIdentifier(taskDescription: task.taskDescription)?.recordID == recordID
      else { continue }
      task.cancel()
    }
  }

  func receiveCompletion(
    taskIdentifier: Int,
    taskDescription: String?,
    result: Result<String, VideoPartUploadFailure>
  ) {
    guard let identifier = VideoUploadPartIdentifier(taskDescription: taskDescription) else {
      return
    }
    let token = BackgroundUploadCompletionRegistry.shared.beginEvent(identifier: sessionIdentifier)
    let continuation = lock.withLock { continuations.removeValue(forKey: taskIdentifier) }
    eventContinuation.yield(
      .part(
        BackgroundVideoPartEvent(
          identifier: identifier,
          result: result,
          completionToken: token,
          hasPipelineContinuation: continuation != nil
        )
      )
    )
    if continuation != nil,
      BackgroundUploadCompletionRegistry.shared.hasPendingHandler(identifier: sessionIdentifier)
    {
      continuation?.resume(throwing: BackgroundUploadPipelineDeferred())
      return
    }
    switch result {
    case .success(let etag):
      continuation?.resume(returning: etag)
    case .failure(let failure):
      continuation?.resume(throwing: failure)
    }
  }

  private func reconnectSession() {
    _ = session
  }

  /// OSS V1 presigned part URLs are signed with an empty Content-Type, but
  /// CFNetwork infers one from the file extension on file-based upload tasks
  /// and OSS then rejects the signature with 403 (2026-08-04 E2E finding).
  /// An explicit empty value stops the inference and matches the signature.
  private static func makePartRequest(url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.timeoutInterval = 60
    request.setValue("", forHTTPHeaderField: "Content-Type")
    return request
  }

  private func makeUploadTask(request: URLRequest, fileURL: URL) -> any BackgroundUploadTask {
    if let uploadTaskFactory {
      return uploadTaskFactory(request, fileURL)
    }
    return session.uploadTask(with: request, fromFile: fileURL)
  }

  private static func result(
    response: URLResponse?,
    error: (any Error)?
  ) -> Result<String, VideoPartUploadFailure> {
    if let urlError = error as? URLError {
      return .failure(urlError.code == .cancelled ? .cancelled : .network(urlError.code))
    }
    if error != nil {
      return .failure(.unknown)
    }
    guard let response = response as? HTTPURLResponse else {
      return .failure(.invalidResponse)
    }
    guard (200..<300).contains(response.statusCode) else {
      return .failure(.httpStatus(response.statusCode))
    }
    guard let rawETag = response.value(forHTTPHeaderField: "etag") else {
      return .failure(.missingETag)
    }
    let etag = rawETag.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    guard !etag.isEmpty else { return .failure(.missingETag) }
    return .success(etag)
  }
}

extension BackgroundVideoPartUploader: URLSessionTaskDelegate, URLSessionDelegate {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    receiveCompletion(
      taskIdentifier: task.taskIdentifier,
      taskDescription: task.taskDescription,
      result: Self.result(response: task.response, error: error)
    )
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    let identifier = session.configuration.identifier ?? sessionIdentifier
    let completionToken = BackgroundUploadCompletionRegistry.shared.beginEvent(
      identifier: identifier
    )
    BackgroundUploadCompletionRegistry.shared.markEventsDelivered(identifier: identifier)
    eventContinuation.yield(
      .sessionEventsFinished(identifier: identifier, completionToken: completionToken)
    )
  }
}
