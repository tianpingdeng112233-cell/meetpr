import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class GrowthCurveViewModel {
  public enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case error(String)
  }

  public enum TimeWindow: String, CaseIterable, Sendable {
    case fourWeeks = "近 4 周"
    case threeMonths = "近 3 月"
    case all = "全部"
  }

  public private(set) var state: State = .idle
  public var selectedFamily: LiftFamily = .squat {
    didSet { refreshVisiblePoints() }
  }
  public var selectedWindow: TimeWindow = .fourWeeks {
    didSet { refreshVisiblePoints() }
  }
  /// Points for the selected family within the selected window, ascending by date.
  public private(set) var visiblePoints: [E1RMHistoryPoint] = []

  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let now: @Sendable () -> Date
  private var historyByFamily: [LiftFamily: [E1RMHistoryPoint]] = [:]

  public init(
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.plans = plans
    self.e1rm = e1rm
    self.now = now
  }

  public func load(studentID: UUID) async {
    state = .loading
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      let idsByFamily = MainLiftExerciseFamilyResolver.exerciseIDsByFamily(in: plan)

      var grouped: [LiftFamily: [E1RMHistoryPoint]] = [:]
      for (family, ids) in idsByFamily {
        let histories = try await e1rm.fetchHistory(studentId: studentID, exerciseIds: Array(ids))
        grouped[family] = histories.values.flatMap { $0 }.sorted { $0.computedAt < $1.computedAt }
      }
      historyByFamily = grouped
      state = .loaded
      refreshVisiblePoints()
    } catch {
      state = .error(error.localizedDescription)
    }
  }

  private func refreshVisiblePoints() {
    let all = historyByFamily[selectedFamily] ?? []
    guard let cutoff = windowCutoff else {
      visiblePoints = all
      return
    }
    visiblePoints = all.filter { $0.computedAt >= cutoff }
  }

  private var windowCutoff: Date? {
    switch selectedWindow {
    case .fourWeeks: now().addingTimeInterval(-28 * 86_400)
    case .threeMonths: now().addingTimeInterval(-90 * 86_400)
    case .all: nil
    }
  }
}
