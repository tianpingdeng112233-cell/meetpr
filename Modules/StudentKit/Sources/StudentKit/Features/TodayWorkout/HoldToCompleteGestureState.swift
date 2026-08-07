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
