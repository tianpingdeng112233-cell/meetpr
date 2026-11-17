import Foundation

/// The manual rest timer's clock and policy, independent of SwiftUI and system effects.
struct RestRingModel: Equatable, Sendable {
  enum Phase: Sendable { case idle, running, done }
  private(set) var phase: Phase = .idle
  private(set) var endsAt: Date?
  private(set) var totalSeconds = 0
  private(set) var exercise = ""
  private var lastRemaining: Int?

  struct Alert: Equatable, Sendable {
    var vibrate: Bool
    var sound: Bool
    static let silent = Self(vibrate: false, sound: false)
  }

  mutating func start(seconds: Int, exercise: String, at now: Date) {
    totalSeconds = min(900, max(0, seconds))
    endsAt = now.addingTimeInterval(TimeInterval(totalSeconds))
    self.exercise = exercise
    phase = .running
    lastRemaining = nil
  }

  @discardableResult
  mutating func adjust(
    by delta: Int, at now: Date, foreground: Bool = true,
    vibration: Bool = true, sound: Bool = true
  ) -> Alert {
    guard phase == .running, let endsAt else { return .silent }
    let seconds = min(900, max(0, endsAt.timeIntervalSince(now) + Double(delta)))
    self.endsAt = now.addingTimeInterval(seconds)
    return tick(at: now, foreground: foreground, vibration: vibration, sound: sound)
  }

  mutating func end() {
    phase = .idle
    endsAt = nil
  }

  mutating func completeToday() { end() }

  func remaining(at now: Date) -> Int {
    guard let endsAt else { return 0 }
    return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
  }

  @discardableResult
  mutating func tick(
    at now: Date, foreground: Bool = true, vibration: Bool = true, sound: Bool = true
  ) -> Alert {
    guard let endsAt else { return .silent }
    let seconds = remaining(at: now)
    let newSecond = seconds != lastRemaining
    let wasRunning = phase == .running
    lastRemaining = seconds
    if now >= endsAt.addingTimeInterval(3) {
      end()
    } else if now >= endsAt {
      phase = .done
    }
    // Never replay missed background beats or a stale completion on return.
    guard wasRunning, foreground, newSecond, seconds <= 10,
      now.timeIntervalSince(endsAt) < 1
    else { return .silent }
    return Alert(vibrate: vibration, sound: sound && seconds == 0)
  }

  static func currentExercise(ids: [UUID], expanded: UUID?, highlighted: UUID?) -> UUID? {
    if let expanded, ids.contains(expanded) { return expanded }
    if let highlighted, ids.contains(highlighted) { return highlighted }
    return ids.last
  }

  static func duration(coachSeconds: Int?, isAccessory: Bool, main: Int, accessory: Int) -> Int {
    min(900, max(0, coachSeconds ?? (isAccessory ? accessory : main)))
  }
}
