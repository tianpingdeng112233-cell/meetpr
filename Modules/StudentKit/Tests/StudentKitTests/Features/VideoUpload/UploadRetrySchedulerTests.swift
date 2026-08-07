import Foundation
import Networking
import Testing

@testable import StudentKit

private let retryEpoch = Date(timeIntervalSince1970: 1_780_000_000)

@Test func retrySchedulerUsesFixedBackoffTable() {
  let scheduler = UploadRetryScheduler()
  let expected: [TimeInterval] = [60, 120, 300, 600, 900]

  for (index, delay) in expected.enumerated() {
    #expect(
      scheduler.decision(
        failure: .transient,
        retryCount: index + 1,
        firstFailureAt: retryEpoch,
        now: retryEpoch,
        networkState: .available
      ) == .retryAfter(delay)
    )
  }
}

@Test func retrySchedulerLetsRestoredNetworkJumpTheQueue() {
  let scheduler = UploadRetryScheduler()
  #expect(
    scheduler.decision(
      failure: .transient,
      retryCount: 3,
      firstFailureAt: retryEpoch,
      now: retryEpoch.addingTimeInterval(60),
      networkState: .restored
    ) == .retryNow
  )
}

@Test func retrySchedulerMakesDeterministicFailureTerminalImmediately() {
  let scheduler = UploadRetryScheduler()
  #expect(
    scheduler.decision(
      failure: .deterministic,
      retryCount: 1,
      firstFailureAt: retryEpoch,
      now: retryEpoch,
      networkState: .available
    ) == .terminalFailure
  )
}

@Test func retrySchedulerEndsAfterFiveRetriesOrThirtyMinutes() {
  let scheduler = UploadRetryScheduler()
  #expect(
    scheduler.decision(
      failure: .transient,
      retryCount: 6,
      firstFailureAt: retryEpoch,
      now: retryEpoch,
      networkState: .available
    ) == .terminalFailure
  )
  #expect(
    scheduler.decision(
      failure: .transient,
      retryCount: 2,
      firstFailureAt: retryEpoch,
      now: retryEpoch.addingTimeInterval(30 * 60),
      networkState: .available
    ) == .terminalFailure
  )
}

@Test func retrySchedulerPreservesRemainingWindowAcrossRestart() {
  let scheduler = UploadRetryScheduler()
  #expect(
    scheduler.decision(
      failure: .transient,
      retryCount: 4,
      firstFailureAt: retryEpoch,
      now: retryEpoch.addingTimeInterval(29 * 60),
      networkState: .unavailable
    ) == .retryAfter(60)
  )
}

@Test func uploadFailureClassificationIsConservativeAndTreatsOSS403AsTransient() {
  #expect(VideoUploadManager.failureKind(for: VideoPartUploadFailure.httpStatus(403)) == .transient)
  #expect(
    VideoUploadManager.failureKind(for: VideoPartUploadFailure.httpStatus(400)) == .deterministic
  )
  #expect(
    VideoUploadManager.failureKind(for: APIError.httpStatus(422, Data())) == .deterministic
  )
  #expect(VideoUploadManager.failureKind(for: MockServiceError.partFailed) == .transient)
}
