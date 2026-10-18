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

  public enum TimeWindow: CaseIterable, Sendable {
    case fourWeeks
    case threeMonths
    case all

    public var displayName: String {
      switch self {
      case .fourWeeks: StudentStrings.localized(.growthCurveViewModel001)
      case .threeMonths: StudentStrings.localized(.growthCurveViewModel002)
      case .all: StudentStrings.localized(.growthCurveViewModel003)
      }
    }
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
  private(set) var visibleSmoothedSamples: [E1RMSeries.Sample] = []
  private(set) var visibleDailyBestSamples: [E1RMSeries.Sample] = []
  private(set) var visibleRawEligiblePoints: [E1RMHistoryPoint] = []

  private let plans: any StudentPlanRepository
  private let logs: (any StudentTrainingLogRepository)?
  private let e1rm: any E1RMRepository
  private let onboarding: (any OnboardingProfileReading)?
  private let reconciler: E1RMCoachRPEReconciler?
  private let now: @Sendable () -> Date
  private var seriesByFamily: [LiftFamily: E1RMSeries] = [:]
  private var rawPointsByID: [UUID: E1RMHistoryPoint] = [:]

  public init(
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: (any OnboardingProfileReading)? = nil,
    logs: (any StudentTrainingLogRepository)? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.plans = plans
    self.e1rm = e1rm
    self.logs = logs
    self.onboarding = onboarding
    self.now = now
    if let logs, let onboarding {
      reconciler = E1RMCoachRPEReconciler(
        logs: logs, onboarding: onboarding, plans: plans,
        catalogReader: plans as? any ExerciseCatalogReading, e1rm: e1rm, now: now
      )
    } else {
      reconciler = nil
    }
  }

  public func load(studentID: UUID) async {
    let isInitialLoad = state == .idle
    if isInitialLoad { state = .loading }
    // Repair stale derived history before the first Progress snapshot. A failed
    // refresh keeps cached history readable and can retry on the next load.
    if let reconciler {
      _ = try? await reconciler.reconcile(studentID: studentID)
    }
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      let profile = try await onboarding?.fetchProfile(studentId: studentID)
      var idsByFamily = MainLiftExerciseFamilyResolver.exerciseIDsByFamily(
        in: plan,
        onboarding: profile
      )

      try await includeAddedHistory(
        studentID: studentID, plan: plan, profile: profile, ids: &idsByFamily)
      var grouped: [LiftFamily: E1RMSeries] = [:]
      var pointsByID: [UUID: E1RMHistoryPoint] = [:]
      for (family, ids) in idsByFamily {
        let histories = try await e1rm.fetchHistory(studentId: studentID, exerciseIds: Array(ids))
        let points = histories.values.flatMap { $0 }
        grouped[family] = E1RMSeries.build(points: points, family: family)
        for point in points {
          pointsByID[point.id] = point
        }
      }
      seriesByFamily = grouped
      rawPointsByID = pointsByID
      state = .loaded
      let rollingWindowStart = now().addingTimeInterval(-E1RMPolicy.rollingWindow)
      // Expansion keys off rawEligible: low-confidence imported points stay out
      // of smoothed but must remain visible as weakened scatter (spec 053 §6).
      if selectedWindow == .fourWeeks,
        grouped.values.flatMap(\.rawEligible).contains(where: { $0.date < rollingWindowStart })
      {
        selectedWindow = .all
      }
      refreshVisiblePoints()
    } catch {
      if error.isTaskCancellation {
        if isInitialLoad { state = .idle }
        return
      }
      if case .loaded = state { return }
      state = .error(error.localizedDescription)
    }
  }

  private func includeAddedHistory(
    studentID: UUID, plan: StudentPlanView?, profile: OnboardingProfile?,
    ids: inout [LiftFamily: Set<UUID>]
  ) async throws {
    do {
      for family in LiftFamily.allCases {
        let stored = try await e1rm.fetchHistory(studentId: studentID, family: family)
        ids[family, default: []].formUnion(stored.map(\.exerciseId))
      }
      if let repository = logs as? any StudentAddedLogRepository {
        let revision = try await e1rm.historySnapshot(studentId: studentID, exerciseIds: [])
          .revision
        let all = try await repository.fetchAllLogs(
          studentID: studentID,
          in: Date(timeIntervalSince1970: 0)...now())
        let catalog: [Exercise]
        if let reader = plans as? any ExerciseCatalogReading {
          catalog = try await reader.fetchExerciseCatalog()
        } else {
          catalog = plan?.days.flatMap(\.exercises).map(\.exercise) ?? []
        }
        try await StudentAddedLedgerRepair.reconcile(
          source: .init(records: all, revision: revision), studentID: studentID,
          days: plan?.days ?? [], catalog: catalog,
          profile: profile, repository: e1rm)
        if all.isAuthoritative && !all.isCompleteLedger {
          await StudentAddedHistory.record(
            all.added, catalog: catalog, e1rm: e1rm, profile: profile)
        }
        for log in all.added {
          if let family = StudentAddedHistory.family(log, catalog: catalog) {
            ids[family, default: []].insert(log.exerciseID)
          }
        }
      }
    } catch {
      if error.isTaskCancellation { throw error }
    }
  }

  private func refreshVisiblePoints() {
    let series =
      seriesByFamily[selectedFamily]
      ?? E1RMSeries.build(points: [], family: selectedFamily)
    let cutoff = windowCutoff
    let currentDate = now()
    let extensionDate = max(series.rawEligible.last?.date ?? currentDate, currentDate)
    visibleSmoothedSamples = E1RMSeries.recordTrajectory(
      records: series.records,
      from: cutoff,
      extendedTo: extensionDate
    )
    let visibleDailyBest = series.dailyBestEligible.filter { sample in
      cutoff.map { sample.date >= $0 } ?? true
    }
    visibleDailyBestSamples = visibleDailyBest.filter {
      $0.winnerConfidence == .normal
    }
    visibleRawEligiblePoints = visibleDailyBest.compactMap { sample in
      guard sample.winnerConfidence == .low else { return nil }
      return rawPointsByID[sample.winnerPointID]
    }
    visiblePoints = E1RMSeries.historyPoints(
      for: visibleSmoothedSamples,
      sourcePoints: Array(rawPointsByID.values)
    )
  }

  func winnerPoint(forSampleID sampleID: UUID) -> E1RMHistoryPoint? {
    guard let sample = visibleSmoothedSamples.first(where: { $0.sampleID == sampleID }) else {
      return nil
    }
    return rawPointsByID[sample.winnerPointID]
  }

  func eligibleDataPointCount(for family: LiftFamily) -> Int {
    seriesByFamily[family]?.dailyBestEligible.count ?? 0
  }

  func visibleDataPointCount(for family: LiftFamily) -> Int {
    let dailyBestEligible = seriesByFamily[family]?.dailyBestEligible ?? []
    let cutoff = windowCutoff
    return dailyBestEligible.count { sample in
      cutoff.map { sample.date >= $0 } ?? true
    }
  }

  func headlinePoint(for family: LiftFamily) -> E1RMHistoryPoint? {
    guard let sample = seriesByFamily[family]?.smoothed.last else {
      return nil
    }
    return rawPointsByID[sample.winnerPointID]
  }

  func sourcePoint(for sample: E1RMSeries.Sample) -> E1RMHistoryPoint? {
    rawPointsByID[sample.winnerPointID]
  }

  func detail(
    forPointID pointID: UUID, logs: [StudentSetLog], days: [StudentPlanDay]
  ) -> GrowthE1RMDetail? {
    guard let point = rawPointsByID[pointID] else { return nil }
    return GrowthE1RMDetail(point: point, logs: logs, days: days)
  }

  private var windowCutoff: Date? {
    switch selectedWindow {
    case .fourWeeks: now().addingTimeInterval(-E1RMPolicy.rollingWindow)
    case .threeMonths: now().addingTimeInterval(-90 * 86_400)
    case .all: nil
    }
  }
}
