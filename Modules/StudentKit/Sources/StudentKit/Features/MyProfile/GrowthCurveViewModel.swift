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
  /// Two-layer chart inputs preserve the rolling winner's provenance instead
  /// of reconstructing it as a default logged point (spec 053 §6).
  private(set) var visibleSmoothedSamples: [E1RMSeries.Sample] = []
  private(set) var visibleRawEligiblePoints: [E1RMHistoryPoint] = []

  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let now: @Sendable () -> Date
  private let mode: TrainingMode
  private let catalog: [Exercise]
  private var seriesByFamily: [LiftFamily: E1RMSeries] = [:]
  private var rawPointsByID: [UUID: E1RMHistoryPoint] = [:]

  public init(
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    now: @escaping @Sendable () -> Date = { Date() },
    mode: TrainingMode = .coached,
    catalog: [Exercise] = []
  ) {
    self.plans = plans
    self.e1rm = e1rm
    self.now = now
    self.mode = mode
    self.catalog = catalog
  }

  public func load(studentID: UUID) async {
    state = .loading
    do {
      // Solo never asks for a plan (spec 047 §1) — catalog buckets instead.
      let plan =
        mode == .selfTrain ? nil : try await plans.fetchCurrentPlan(studentID: studentID)
      let idsByFamily = MainLiftExerciseFamilyResolver.exerciseIDsByFamily(
        in: plan, catalog: catalog)

      var grouped: [LiftFamily: E1RMSeries] = [:]
      var pointsByID: [UUID: E1RMHistoryPoint] = [:]
      for (family, ids) in idsByFamily {
        let histories = try await e1rm.fetchHistory(studentId: studentID, exerciseIds: Array(ids))
        // Single aggregation (spec 050 §2): the growth curve draws the
        // eligibility-gated rolling-max line, so one anomalous set no longer
        // tops the chart by 25 kg.
        let points = histories.values.flatMap { $0 }
        grouped[family] = E1RMSeries.build(points: points, family: family)
        for point in points {
          pointsByID[point.id] = point
        }
      }
      seriesByFamily = grouped
      rawPointsByID = pointsByID
      state = .loaded
      if selectedWindow == .fourWeeks,
        grouped.values.flatMap(\.smoothed).contains(where: {
          $0.date < now().addingTimeInterval(-28 * 86_400)
        })
      {
        // An imported timeline is history first: do not make its first visible
        // chart silently empty just because the default picker said 4 weeks.
        selectedWindow = .all
      }
      refreshVisiblePoints()
    } catch {
      if error.isTaskCancellation {
        state = .idle
        return
      }
      state = .error(error.localizedDescription)
    }
  }

  private func refreshVisiblePoints() {
    let series =
      seriesByFamily[selectedFamily] ?? E1RMSeries.build(points: [], family: selectedFamily)
    let cutoff = windowCutoff
    visibleSmoothedSamples = series.smoothed.filter { sample in
      cutoff.map { sample.date >= $0 } ?? true
    }
    visibleRawEligiblePoints = series.rawEligible.compactMap { sample in
      guard cutoff.map({ sample.date >= $0 }) ?? true else { return nil }
      return rawPointsByID[sample.winnerPointID]
    }
    visiblePoints = visibleSmoothedSamples.compactMap { sample in
      guard let winner = rawPointsByID[sample.winnerPointID] else { return nil }
      return E1RMHistoryPoint(
        id: sample.sampleID,
        studentId: winner.studentId,
        exerciseId: winner.exerciseId,
        setLogId: winner.setLogId,
        computedAt: sample.date,
        e1RMKg: sample.valueKg,
        sourceWeightKg: winner.sourceWeightKg,
        sourceReps: winner.sourceReps,
        sourceRPE: winner.sourceRPE,
        confidence: sample.winnerConfidence,
        origin: sample.winnerOrigin
      )
    }
  }

  func winnerPoint(forSampleID sampleID: UUID) -> E1RMHistoryPoint? {
    guard let sample = visibleSmoothedSamples.first(where: { $0.sampleID == sampleID }) else {
      return nil
    }
    return rawPointsByID[sample.winnerPointID]
  }

  private var windowCutoff: Date? {
    switch selectedWindow {
    case .fourWeeks: now().addingTimeInterval(-28 * 86_400)
    case .threeMonths: now().addingTimeInterval(-90 * 86_400)
    case .all: nil
    }
  }
}
