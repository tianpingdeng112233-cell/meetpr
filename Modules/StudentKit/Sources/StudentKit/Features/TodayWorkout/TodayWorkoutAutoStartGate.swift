struct TodayWorkoutAutoStartGate: Equatable, Sendable {
  private(set) var pendingToken: Int?
  private(set) var lastConsumedToken = 0

  mutating func receive(token: Int) {
    // Monotonic: a stale token replayed after an await must never downgrade
    // a newer pending token delivered in the meantime.
    guard token > max(lastConsumedToken, pendingToken ?? 0) else { return }
    pendingToken = token
  }

  mutating func consumeIfReady(isTargetDateLoaded: Bool) -> Bool {
    guard isTargetDateLoaded, let pendingToken else { return false }
    lastConsumedToken = pendingToken
    self.pendingToken = nil
    return true
  }
}
