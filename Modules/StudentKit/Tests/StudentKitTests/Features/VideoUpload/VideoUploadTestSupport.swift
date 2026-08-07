import CoreModels
import Foundation
import Networking
import RepositoryContracts

@testable import StudentKit

/// Records the wire-call order of the upload pipeline and lets tests inject
/// per-part failures, complete errors, and a hang (for cancellation tests).
actor MockVideoUploadService: VideoUploadService {
  let remoteAttachmentID = UUID()
  nonisolated let backgroundSessionIdentifier = "mock-video-upload-\(UUID().uuidString)"
  nonisolated let backgroundEvents: AsyncStream<BackgroundVideoUploadEvent>
  nonisolated let backgroundEventContinuation: AsyncStream<BackgroundVideoUploadEvent>.Continuation

  private(set) var calls: [String] = []
  private(set) var partAttempts: [Int: Int] = [:]
  private(set) var abortCount = 0
  private(set) var cancelPartsCount = 0
  private(set) var cancelLegacyPartsCount = 0
  private(set) var schedulePartAttemptCount = 0
  private(set) var scheduledPartIdentifiers: [VideoUploadPartIdentifier] = []
  private(set) var suspendedCancelLegacyPartsCount = 0
  private(set) var suspendedPendingPartNumbersCount = 0
  private(set) var suspendedCancelPartsCount = 0
  private(set) var pendingPartNumbersCallCount = 0
  private(set) var backgroundWakeCheckCallCount = 0
  private(set) var suspendedBackgroundWakeCheckCount = 0

  private var partFailuresRemaining: [Int: Int] = [:]
  private var signatureFailuresRemaining: [Int: Int] = [:]
  private var deterministicFailuresRemaining: [Int: Int] = [:]
  private var completeError: Error?
  private var queuedCompleteErrors: [any Error] = []
  private var completeDelay: Duration?
  private var hangOnParts = false
  private var partDelay: Duration?
  private var pendingParts: Set<Int> = []
  private var hasLegacyPendingParts = false
  private var abortFailuresRemaining = 0
  private var schedulePartSuspensionsRemaining = 0
  private var schedulePartWaiters: [CheckedContinuation<Void, Never>] = []
  private var cancelLegacyPartsSuspensionsRemaining = 0
  private var cancelLegacyPartsWaiters: [CheckedContinuation<Void, Never>] = []
  private var pendingPartNumbersSuspensionsRemaining = 0
  private var pendingPartNumbersWaiters: [CheckedContinuation<Void, Never>] = []
  private var cancelPartsSuspensionsRemaining = 0
  private var cancelPartsWaiters: [CheckedContinuation<Void, Never>] = []
  private var backgroundWakeCheckSuspensionCall: Int?
  private var backgroundWakeCheckWaiters: [CheckedContinuation<Void, Never>] = []
  private(set) var backgroundCancellationClaim: BackgroundUploadCancellationClaim?

  init() {
    let stream = AsyncStream.makeStream(
      of: BackgroundVideoUploadEvent.self,
      bufferingPolicy: .bufferingNewest(20)
    )
    backgroundEvents = stream.stream
    backgroundEventContinuation = stream.continuation
  }

  func setPartFailures(_ failures: [Int: Int]) {
    partFailuresRemaining = failures
  }

  func setSignatureFailures(_ failures: [Int: Int]) {
    signatureFailuresRemaining = failures
  }

  func setDeterministicFailures(_ failures: [Int: Int]) {
    deterministicFailuresRemaining = failures
  }

  func setCompleteError(_ error: Error?) {
    completeError = error
  }

  func setCompleteErrors(_ errors: [any Error]) {
    queuedCompleteErrors = errors
  }

  func setCompleteDelay(_ delay: Duration?) {
    completeDelay = delay
  }

  func setHangOnParts(_ hang: Bool) {
    hangOnParts = hang
  }

  func setPartDelay(_ delay: Duration?) {
    partDelay = delay
  }

  func setPendingParts(_ partNumbers: Set<Int>) {
    pendingParts = partNumbers
  }

  func setHasLegacyPendingParts(_ hasLegacyParts: Bool) {
    hasLegacyPendingParts = hasLegacyParts
  }

  func setAbortFailures(_ count: Int) {
    abortFailuresRemaining = count
  }

  func suspendNextSchedulePart() {
    schedulePartSuspensionsRemaining += 1
  }

  func releaseScheduledParts() {
    let waiters = schedulePartWaiters
    schedulePartWaiters = []
    for waiter in waiters {
      waiter.resume()
    }
  }

  func suspendNextCancelLegacyParts() {
    cancelLegacyPartsSuspensionsRemaining += 1
  }

  func releaseCancelLegacyParts() {
    let waiters = cancelLegacyPartsWaiters
    cancelLegacyPartsWaiters = []
    for waiter in waiters {
      waiter.resume()
    }
  }

  func suspendNextPendingPartNumbers() {
    pendingPartNumbersSuspensionsRemaining += 1
  }

  func releasePendingPartNumbers() {
    let waiters = pendingPartNumbersWaiters
    pendingPartNumbersWaiters = []
    for waiter in waiters {
      waiter.resume()
    }
  }

  func suspendNextCancelParts() {
    cancelPartsSuspensionsRemaining += 1
  }

  func releaseCancelParts() {
    let waiters = cancelPartsWaiters
    cancelPartsWaiters = []
    for waiter in waiters {
      waiter.resume()
    }
  }

  func suspendBackgroundWakeCheck(call: Int) {
    backgroundWakeCheckSuspensionCall = call
  }

  func releaseBackgroundWakeChecks() {
    let waiters = backgroundWakeCheckWaiters
    backgroundWakeCheckWaiters = []
    for waiter in waiters {
      waiter.resume()
    }
  }

  func emitBackgroundEvent(_ event: BackgroundVideoPartEvent) {
    let token = BackgroundUploadCompletionRegistry.shared.beginEvent(
      identifier: backgroundSessionIdentifier
    )
    backgroundEventContinuation.yield(
      .part(
        BackgroundVideoPartEvent(
          identifier: event.identifier,
          result: event.result,
          completionToken: token,
          hasPipelineContinuation: event.hasPipelineContinuation
        )
      )
    )
  }

  func finishBackgroundEvents() {
    let completionToken = BackgroundUploadCompletionRegistry.shared.beginEvent(
      identifier: backgroundSessionIdentifier
    )
    BackgroundUploadCompletionRegistry.shared.markEventsDelivered(
      identifier: backgroundSessionIdentifier
    )
    backgroundEventContinuation.yield(
      .sessionEventsFinished(
        identifier: backgroundSessionIdentifier,
        completionToken: completionToken
      )
    )
  }

  func initiate(_ request: InitiateUploadRequestDTO) async throws -> InitiateUploadResponseDTO {
    calls.append("initiate:\(request.partCount):\(request.filename ?? "-")")
    let partURLs = (1...request.partCount).map { partNumber in
      UploadPartURLDTO(partNumber: partNumber, url: "https://oss.test/parts/\(partNumber)")
    }
    return InitiateUploadResponseDTO(
      attachmentID: remoteAttachmentID,
      uploadID: "upload-1",
      partURLs: partURLs
    )
  }

  func uploadPart(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws -> String {
    _ = try Data(contentsOf: fileURL)
    let partNumber = Int(url.lastPathComponent) ?? 0
    calls.append("part:\(partNumber)")
    partAttempts[partNumber, default: 0] += 1
    if hangOnParts {
      try await Task.sleep(for: .seconds(60))
    }
    if let partDelay {
      try await Task.sleep(for: partDelay)
    }
    if let remaining = signatureFailuresRemaining[partNumber], remaining > 0 {
      signatureFailuresRemaining[partNumber] = remaining - 1
      throw VideoPartUploadFailure.httpStatus(403)
    }
    if let remaining = deterministicFailuresRemaining[partNumber], remaining > 0 {
      deterministicFailuresRemaining[partNumber] = remaining - 1
      throw VideoPartUploadFailure.httpStatus(400)
    }
    if let remaining = partFailuresRemaining[partNumber], remaining > 0 {
      partFailuresRemaining[partNumber] = remaining - 1
      throw MockServiceError.partFailed
    }
    return "etag-\(partNumber)"
  }

  func schedulePart(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws {
    _ = try Data(contentsOf: fileURL)
    schedulePartAttemptCount += 1
    if schedulePartSuspensionsRemaining > 0 {
      schedulePartSuspensionsRemaining -= 1
      await withCheckedContinuation { continuation in
        schedulePartWaiters.append(continuation)
      }
    }
    calls.append("schedule:\(identifier.partNumber)")
    scheduledPartIdentifiers.append(identifier)
    pendingParts.insert(identifier.partNumber)
  }

  func complete(attachmentID: UUID, parts: [UploadPartETagDTO]) async throws -> AttachmentDTO {
    let partList = parts.map { String($0.partNumber) }.joined(separator: ",")
    calls.append("complete:\(partList)")
    if let completeDelay {
      try await Task.sleep(for: completeDelay)
    }
    if !queuedCompleteErrors.isEmpty {
      throw queuedCompleteErrors.removeFirst()
    }
    if let completeError {
      throw completeError
    }
    return AttachmentDTO(
      id: attachmentID,
      ownerID: UUID(),
      kind: .setVideo,
      ossKey: "attachments/test/\(attachmentID.uuidString).mp4",
      contentType: "video/mp4",
      sizeBytes: 1,
      filename: nil,
      status: .ready,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

}

extension MockVideoUploadService {
  func abort(attachmentID: UUID) async throws {
    calls.append("abort")
    abortCount += 1
    if abortFailuresRemaining > 0 {
      abortFailuresRemaining -= 1
      throw MockServiceError.partFailed
    }
  }

  func isBackgroundWakeActive() async -> Bool {
    backgroundWakeCheckCallCount += 1
    if backgroundWakeCheckSuspensionCall == backgroundWakeCheckCallCount {
      suspendedBackgroundWakeCheckCount += 1
      await withCheckedContinuation { continuation in
        backgroundWakeCheckWaiters.append(continuation)
      }
      backgroundWakeCheckSuspensionCall = nil
    }
    return BackgroundUploadCompletionRegistry.shared.hasPendingHandler(
      identifier: backgroundSessionIdentifier
    )
  }

  func pendingPartNumbers(recordID: UUID, generation: Int) async -> Set<Int> {
    pendingPartNumbersCallCount += 1
    if pendingPartNumbersSuspensionsRemaining > 0 {
      pendingPartNumbersSuspensionsRemaining -= 1
      suspendedPendingPartNumbersCount += 1
      await withCheckedContinuation { continuation in
        pendingPartNumbersWaiters.append(continuation)
      }
    }
    return pendingParts
  }

  func cancelLegacyParts(recordID: UUID) async -> Bool {
    if cancelLegacyPartsSuspensionsRemaining > 0 {
      cancelLegacyPartsSuspensionsRemaining -= 1
      suspendedCancelLegacyPartsCount += 1
      await withCheckedContinuation { continuation in
        cancelLegacyPartsWaiters.append(continuation)
      }
    }
    guard hasLegacyPendingParts else { return false }
    hasLegacyPendingParts = false
    cancelLegacyPartsCount += 1
    return true
  }

  func cancelParts(recordID: UUID) async {
    cancelPartsCount += 1
    if cancelPartsSuspensionsRemaining > 0 {
      cancelPartsSuspensionsRemaining -= 1
      suspendedCancelPartsCount += 1
      await withCheckedContinuation { continuation in
        cancelPartsWaiters.append(continuation)
      }
    }
    pendingParts = []
    hasLegacyPendingParts = false
  }

  func claimBackgroundCancellation() async -> BackgroundUploadCancellationClaim? {
    guard await !isBackgroundWakeActive(), backgroundCancellationClaim == nil else { return nil }
    let claim = BackgroundUploadCancellationClaim(
      sessionIdentifier: backgroundSessionIdentifier
    )
    backgroundCancellationClaim = claim
    return claim
  }

  func cancelParts(recordID: UUID, claim: BackgroundUploadCancellationClaim) async {
    guard backgroundCancellationClaim == claim else { return }
    await cancelParts(recordID: recordID)
    backgroundCancellationClaim = nil
  }

  func releaseBackgroundCancellationClaim(_ claim: BackgroundUploadCancellationClaim) {
    guard backgroundCancellationClaim == claim else { return }
    backgroundCancellationClaim = nil
  }
}
