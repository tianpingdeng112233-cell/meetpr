import Foundation

extension Error {
  /// `true` when this is a cancelled async task rather than a genuine failure.
  ///
  /// SwiftUI may cancel a tab's first-load `.task` while the signed-in subtree
  /// settles. Depending on where cancellation reaches the networking stack,
  /// that surfaces as either `CancellationError` or `URLError.cancelled`.
  /// Load view models return to `.idle` so the rebuilt `.task` can retry.
  var isTaskCancellation: Bool {
    self is CancellationError || (self as? URLError)?.code == .cancelled
  }
}
