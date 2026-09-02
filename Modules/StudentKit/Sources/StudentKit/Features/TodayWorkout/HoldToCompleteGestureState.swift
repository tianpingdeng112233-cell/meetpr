struct HoldToCompleteGestureState: Equatable, Sendable {
  enum Phase: Equatable, Sendable {
    case idle
    case holding
    case cancelledUntilEnded
    case completedUntilEnded
  }

  enum Action: Equatable, Sendable {
    case begin
    case cancel
    case complete
    case reset
  }

  private(set) var phase: Phase = .idle

  var isHolding: Bool {
    phase == .holding
  }

  mutating func dragChanged(isWithinBounds: Bool) -> Action? {
    switch phase {
    case .idle:
      guard isWithinBounds else {
        phase = .cancelledUntilEnded
        return nil
      }
      phase = .holding
      return .begin
    case .holding:
      guard !isWithinBounds else { return nil }
      phase = .cancelledUntilEnded
      return .cancel
    case .cancelledUntilEnded, .completedUntilEnded:
      return nil
    }
  }

  mutating func holdCompleted() -> Action? {
    guard phase == .holding else { return nil }
    phase = .completedUntilEnded
    return .complete
  }

  mutating func dragEnded() -> Action? {
    switch phase {
    case .idle:
      return nil
    case .holding:
      phase = .idle
      return .cancel
    case .cancelledUntilEnded, .completedUntilEnded:
      phase = .idle
      return .reset
    }
  }
}

enum HoldToCompleteHapticWeight: Equatable, Sendable {
  case light
  case medium
  case heavy
}

struct HoldToCompleteHapticSchedule {
  struct Feedback: Equatable, Sendable {
    let weight: HoldToCompleteHapticWeight
    let intensity: Double
  }

  static func feedback(forStep step: Int) -> Feedback {
    switch step {
    case ...2:
      Feedback(weight: .light, intensity: 0.5)
    case 3:
      Feedback(weight: .medium, intensity: 0.7)
    case 4:
      Feedback(weight: .medium, intensity: 0.775)
    case 5:
      Feedback(weight: .medium, intensity: 0.85)
    default:
      Feedback(weight: .heavy, intensity: 1)
    }
  }
}
