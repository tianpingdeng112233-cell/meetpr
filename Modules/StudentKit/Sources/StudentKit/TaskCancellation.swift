import Foundation

extension Error {
  /// `true` when this is a cancelled async task rather than a genuine failure.
  ///
  /// A SwiftUI `.task` cancelled mid-flight — the signed-in view subtree gets
  /// re-identified during the post-login settling window, which cancels the
  /// tabs' still-in-flight first-load `.task`s — throws `CancellationError` or
  /// `URLError.cancelled` (-999). High latency (e.g. UK → 阿里云) widens the
  /// race so the request is cancelled before it returns.
  ///
  /// Student load view models treat this as "retry pending", not a failure:
  /// they avoid `state = .error(...)` so the rebuilt `.task` reloads instead of
  /// flashing a spurious "加载失败 / cancelled".
  var isTaskCancellation: Bool {
    self is CancellationError || (self as? URLError)?.code == .cancelled
  }
}
