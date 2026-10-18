import Foundation

extension Error {
  /// Cancellation is a lifecycle event, not a failed load. URLSession passes
  /// cancellation through as URLError; structured tasks use CancellationError.
  public var isTaskCancellation: Bool {
    self is CancellationError || (self as? URLError)?.code == .cancelled
  }
}
