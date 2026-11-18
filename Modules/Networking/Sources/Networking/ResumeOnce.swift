import Foundation

/// Delivers only the first result from a callback-based API, even if callbacks race.
/// The resumer is consumed under the lock and invoked after unlocking, allowing reentry.
public final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
  // All access to the mutable resumer is protected by lock.
  private let lock = NSLock()
  private var resumer: (@Sendable (Result<Value, any Error>) -> Void)?

  public init(_ resumer: @escaping @Sendable (Result<Value, any Error>) -> Void) {
    self.resumer = resumer
  }

  public func resume(with result: Result<Value, any Error>) {
    let resumer = lock.withLock {
      defer { self.resumer = nil }
      return self.resumer
    }
    resumer?(result)
  }
}
