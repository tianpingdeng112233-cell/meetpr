import CoreModels
import Foundation
import Observation

/// Coach-side e1RM growth curve backed by the same server aggregates as web.
/// No local set-log calculation or fallback is allowed here: eligibility and
/// rounding policy are owned by the backend.
@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class StudentGrowthViewModel {
  enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  enum TimeWindow: CaseIterable, Sendable {
    case fourWeeks
    case threeMonths
    case all

    var title: String {
      switch self {
      case .fourWeeks: CoachStudentDetailStrings.text("coach.growth.window.fourWeeks")
      case .threeMonths: CoachStudentDetailStrings.text("coach.growth.window.threeMonths")
      case .all: CoachStudentDetailStrings.text("coach.growth.window.all")
      }
    }
  }

  struct GrowthPoint: Hashable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let e1RMKg: Decimal
  }

  private(set) var state: LoadState = .idle
  var selectedFamily: LiftFamily = .squat {
    didSet { refreshVisiblePoints() }
  }
  var selectedWindow: TimeWindow = .fourWeeks {
    didSet { refreshVisiblePoints() }
  }
  /// Points for the selected family within the selected window, ascending.
  private(set) var visiblePoints: [GrowthPoint] = []

  /// Plateau read for the selected family. The detector still owns its
  /// presentation-only Double math; source values remain exact Decimal.
  var plateau: E1RMPlateauDetector.Result {
    let points = (pointsByFamily[selectedFamily] ?? []).map {
      E1RMPlateauDetector.Point(
        date: $0.date,
        e1RMKg: NSDecimalNumber(decimal: $0.e1RMKg).doubleValue
      )
    }
    return E1RMPlateauDetector.detect(points: points)
  }

  @ObservationIgnored private let exerciseStats: any CoachExerciseStatsProviding
  private var referenceDate: Date?
  private var pointsByFamily: [LiftFamily: [GrowthPoint]] = [:]
  private var e1RMByFamily: [LiftFamily: Decimal] = [:]
  private var trendByFamily: [LiftFamily: CoachExerciseStatsSnapshot.Trend] = [:]
  private(set) var oneRMByFamily: [LiftFamily: Decimal] = [:]

  init(exerciseStats: any CoachExerciseStatsProviding) {
    self.exerciseStats = exerciseStats
  }

  func loadIfNeeded(studentID: UUID, now: Date) async {
    guard state == .idle else { return }
    await load(studentID: studentID, now: now)
  }

  func load(studentID: UUID, now currentDate: Date) async {
    state = .loading
    referenceDate = currentDate
    do {
      let snapshot = try await exerciseStats.fetchExerciseStats(studentID: studentID)
      pointsByFamily = snapshot.seriesByFamily.mapValues { series in
        series.points.map { point in
          GrowthPoint(id: UUID(), date: point.date, e1RMKg: point.valueKg)
        }
      }
      e1RMByFamily = snapshot.e1RMByFamily.mapValues(\.valueKg)
      trendByFamily = snapshot.seriesByFamily.mapValues(\.trend)
      oneRMByFamily = snapshot.oneRMByFamily
      state = .loaded
      refreshVisiblePoints()
    } catch {
      state = .failed(CoachGrowthStrings.loadFailed)
    }
  }

  func points(for family: LiftFamily) -> [GrowthPoint] {
    pointsByFamily[family] ?? []
  }

  func headlineE1RM(for family: LiftFamily) -> Decimal? {
    e1RMByFamily[family]
  }

  func trend(for family: LiftFamily) -> CoachExerciseStatsSnapshot.Trend? {
    trendByFamily[family]
  }

  var latestTotal: Decimal? {
    let values = LiftFamily.allCases.compactMap { e1RMByFamily[$0] }
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +)
  }

  var oneRMTotal: Decimal {
    LiftFamily.allCases.compactMap { oneRMByFamily[$0] }.reduce(0, +)
  }

  private func refreshVisiblePoints() {
    let all = pointsByFamily[selectedFamily] ?? []
    guard let cutoff = windowCutoff else {
      visiblePoints = all
      return
    }
    visiblePoints = all.filter { $0.date >= cutoff }
  }

  private var windowCutoff: Date? {
    guard let referenceDate else {
      return nil
    }
    switch selectedWindow {
    case .fourWeeks: return referenceDate.addingTimeInterval(-28 * 86_400)
    case .threeMonths: return referenceDate.addingTimeInterval(-90 * 86_400)
    case .all: return nil
    }
  }
}
