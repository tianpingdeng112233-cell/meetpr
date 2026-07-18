import RepositoryContracts

public actor InMemoryCoachDashboardRepository: CoachDashboardRepository {
  private let signals: [CoachSignal]
  private let dailyDigestBody: String?

  public init(signals: [CoachSignal] = [], dailyDigestBody: String? = nil) {
    self.signals = signals
    self.dailyDigestBody = dailyDigestBody
  }

  public func fetchOpenSignals() async throws -> [CoachSignal] {
    signals
  }

  public func fetchDailyDigestBody() async -> String? {
    dailyDigestBody
  }
}
