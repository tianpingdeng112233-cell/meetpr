import Foundation

@MainActor
public protocol RestTimerActivityControlling: Sendable {
  func start(endsAt: Date, totalSeconds: Int)
  func update(endsAt: Date, totalSeconds: Int)
  func end()
}

public struct NoOpRestTimerActivityController: RestTimerActivityControlling {
  public init() {}

  public func start(endsAt: Date, totalSeconds: Int) {}

  public func update(endsAt: Date, totalSeconds: Int) {}

  public func end() {}
}
