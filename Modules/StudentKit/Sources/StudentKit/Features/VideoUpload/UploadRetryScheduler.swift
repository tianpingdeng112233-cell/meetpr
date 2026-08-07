import Foundation

/// Pure retry policy for a whole video-upload pipeline.
public struct UploadRetryScheduler: Sendable {
  public enum FailureKind: Equatable, Sendable {
    case transient
    case deterministic
  }

  public enum NetworkState: Equatable, Sendable {
    case available
    case unavailable
    case restored
  }

  public enum Decision: Equatable, Sendable {
    case retryNow
    case retryAfter(TimeInterval)
    case terminalFailure
  }

  public let backoffSeconds: [TimeInterval]
  public let timeBoxSeconds: TimeInterval

  public init(
    backoffSeconds: [TimeInterval] = [60, 120, 300, 600, 900],
    timeBoxSeconds: TimeInterval = 30 * 60
  ) {
    precondition(!backoffSeconds.isEmpty)
    precondition(backoffSeconds.allSatisfy { $0 >= 0 })
    precondition(timeBoxSeconds > 0)
    self.backoffSeconds = backoffSeconds
    self.timeBoxSeconds = timeBoxSeconds
  }

  public func decision(
    failure: FailureKind,
    retryCount: Int,
    firstFailureAt: Date,
    now: Date,
    networkState: NetworkState
  ) -> Decision {
    guard failure == .transient else { return .terminalFailure }
    let elapsed = max(0, now.timeIntervalSince(firstFailureAt))
    let remaining = timeBoxSeconds - elapsed
    guard remaining > 0, retryCount > 0, retryCount <= backoffSeconds.count else {
      return .terminalFailure
    }
    if networkState == .restored {
      return .retryNow
    }
    return .retryAfter(min(backoffSeconds[retryCount - 1], remaining))
  }
}
