import Observation
import RepositoryContracts

@Observable
@MainActor
final class CoachDashboardViewModel {
  enum LoadState: Equatable, Sendable {
    case loading
    case loaded
    case failed
  }

  private(set) var signals: [CoachSignal] = []
  private(set) var dailyDigestBody: String?
  private(set) var loadState: LoadState = .loading

  @ObservationIgnored private let repository: any CoachDashboardRepository
  @ObservationIgnored private var loadingTask: Task<Void, Never>?

  init(repository: any CoachDashboardRepository) {
    self.repository = repository
  }

  func loadIfNeeded() async {
    guard loadState != .loaded else { return }
    await load()
  }

  func reload() async {
    await load()
  }

  private func load() async {
    if let loadingTask {
      await loadingTask.value
      return
    }
    loadState = .loading
    let task = Task { [weak self] in
      guard let self else { return }
      await performLoad()
    }
    loadingTask = task
    await task.value
    loadingTask = nil
  }

  private func performLoad() async {
    async let digest = repository.fetchDailyDigestBody()
    do {
      signals = Self.sort(try await repository.fetchOpenSignals())
      loadState = .loaded
    } catch {
      loadState = .failed
    }
    dailyDigestBody = await digest
  }

  private static func sort(_ signals: [CoachSignal]) -> [CoachSignal] {
    signals.sorted { lhs, rhs in
      let lhsRank = severityRank(lhs.severity)
      let rhsRank = severityRank(rhs.severity)
      if lhsRank != rhsRank {
        return lhsRank < rhsRank
      }
      return lhs.openedAt > rhs.openedAt
    }
  }

  private static func severityRank(_ severity: CoachSignalSeverity) -> Int {
    switch severity {
    case .red:
      0
    case .yellow:
      1
    case .green:
      2
    }
  }
}
