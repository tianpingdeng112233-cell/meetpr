import Foundation

@MainActor
public protocol RestTimerActivityControlling: Sendable {
  func start(endsAt: Date, totalSeconds: Int)
  func update(endsAt: Date, totalSeconds: Int)
  func setAlerts(sound: Bool, vibration: Bool)
  func setForeground(_ active: Bool)
  func end()
}

public struct NoOpRestTimerActivityController: RestTimerActivityControlling {
  public init() {}

  public func start(endsAt: Date, totalSeconds: Int) {}

  public func update(endsAt: Date, totalSeconds: Int) {}

  public func end() {}
}

extension RestTimerActivityControlling {
  public func setAlerts(sound: Bool, vibration: Bool) {}
  public func setForeground(_ active: Bool) {}
}
