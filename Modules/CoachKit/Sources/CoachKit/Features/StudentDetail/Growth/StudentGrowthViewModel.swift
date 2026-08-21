import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Coach-side e1RM growth curve (spec 029 §2.7, second pass). The coach
/// device holds no local e1RM history (spec 028 keeps it on the student's
/// device), so this recomputes from the student's completed set logs with
/// the shared `CoreModels.E1RMCalculator` — the exact pure function the
/// student side runs, so both ends agree by construction.
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
    /// The source set log's id — stable across reloads.
    let id: UUID
    let date: Date
    let e1RMKg: Double
  }

  /// Log fetch horizon. "全部" is bounded by this fetch window in V0.1 —
  /// full history needs the cross-device e1RM backend (spec 028 ladder).
  static let fetchDays = 90

  private(set) var state: LoadState = .idle
  var selectedFamily: LiftFamily = .squat {
    didSet { refreshVisiblePoints() }
  }
  var selectedWindow: TimeWindow = .fourWeeks {
    didSet { refreshVisiblePoints() }
  }
  /// Points for the selected family within the selected window, ascending.
  private(set) var visiblePoints: [GrowthPoint] = []

  /// Plateau read for the selected family (coach-analytics-v1 §2, A-group #4).
  /// Computed over ALL points for the family — not the chart's selected window
  /// — so a multi-week stall is detectable regardless of the visible range.
  /// Soft signal only (a banner cue), never a gate. UI/UX is the designer's;
  /// this exposes `isPlateau` / `weeksStalled` for the view to render.
  var plateau: E1RMPlateauDetector.Result {
    let points = (pointsByFamily[selectedFamily] ?? []).map {
      E1RMPlateauDetector.Point(date: $0.date, e1RMKg: $0.e1RMKg)
    }
    return E1RMPlateauDetector.detect(points: points)
  }

  @ObservationIgnored private let plans: any StudentPlanRepository
  @ObservationIgnored private let trainingLogs: any StudentTrainingLogRepository
  @ObservationIgnored private let profiles: any OnboardingProfileReading
  @ObservationIgnored private let familyMapProvider: (any CoachPlanFamilyMapProviding)?
  private var referenceDate: Date?
  private var pointsByFamily: [LiftFamily: [GrowthPoint]] = [:]
  private(set) var oneRMByFamily: [LiftFamily: Decimal] = [:]

  init(
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    profiles: any OnboardingProfileReading = InMemoryCoachStudentProfileReader(),
    familyMapProvider: (any CoachPlanFamilyMapProviding)? = nil
  ) {
    self.plans = plans
    self.trainingLogs = trainingLogs
    self.profiles = profiles
    self.familyMapProvider = familyMapProvider
  }

  func loadIfNeeded(studentID: UUID, now: Date) async {
    guard state == .idle else { return }
    await load(studentID: studentID, now: now)
  }

  func load(studentID: UUID, now currentDate: Date) async {
    state = .loading
    referenceDate = currentDate
    do {
      // The student projection only carries the current week (publish
      // filters by weekIndex), so the coach-owned full plan tree is the
      // primary family source; the projection remains a fallback so the tab
      // degrades instead of blanking when the tree fetch fails (Codex P1).
      let onboarding = try await profiles.fetchProfile(studentId: studentID)
      oneRMByFamily = Self.oneRMByFamily(onboarding)
      var familyMap: [UUID: LiftFamily] = [:]
      if let provider = familyMapProvider {
        familyMap =
          (try? await provider.familyMap(traineeID: studentID, onboarding: onboarding)) ?? [:]
      }
      if familyMap.isEmpty {
        let cycleDays = try await plans.fetchCycleDays(studentID: studentID)
        familyMap = Self.familyByPlanExerciseID(days: cycleDays, onboarding: onboarding)
      }
      let end = currentDate
      let start =
        CoachFeatureCalendar.calendar.date(byAdding: .day, value: -Self.fetchDays, to: end)
        ?? end.addingTimeInterval(-Double(Self.fetchDays) * 86_400)
      let logs = try await trainingLogs.fetchLogs(studentID: studentID, in: start...end)
      pointsByFamily = Self.makePoints(
        logs: logs,
        familyByPlanExerciseID: familyMap
      )
      state = .loaded
      refreshVisiblePoints()
    } catch {
      state = .failed(CoachStudentDetailStrings.text("coach.growth.error.load"))
    }
  }

  func points(for family: LiftFamily) -> [GrowthPoint] {
    pointsByFamily[family] ?? []
  }

  func latestPoint(for family: LiftFamily) -> GrowthPoint? {
    points(for: family).last
  }

  func gain(for family: LiftFamily) -> Double? {
    let points = points(for: family)
    guard let first = points.first, let last = points.last else { return nil }
    return last.e1RMKg - first.e1RMKg
  }

  var latestTotal: Double {
    LiftFamily.allCases.compactMap { latestPoint(for: $0)?.e1RMKg }.reduce(0, +)
  }

  var oneRMTotal: Decimal {
    LiftFamily.allCases.compactMap { oneRMByFamily[$0] }.reduce(0, +)
  }

  private static func oneRMByFamily(
    _ profile: OnboardingProfile?
  ) -> [LiftFamily: Decimal] {
    guard let profile else { return [:] }
    return [
      .squat: profile.squat1RMKg,
      .bench: profile.bench1RMKg,
      .deadlift: profile.deadlift1RMKg,
    ].compactMapValues { $0 }
  }

  /// Main-lift plan exercises only — accessories carry no lift family.
  static func familyByPlanExerciseID(
    days: [StudentPlanDay],
    onboarding: OnboardingProfile? = nil
  ) -> [UUID: LiftFamily] {
    var families: [UUID: LiftFamily] = [:]
    for day in days {
      for slot in day.exercises {
        guard
          let family = resolveCompetitionFamily(
            exercise: slot.exercise,
            onboarding: onboarding
          )
        else { continue }
        families[slot.id] = family
      }
    }
    return families
  }

  /// Completed logs only; logs whose plan exercise is unknown (older cycle)
  /// or whose inputs the calculator rejects are dropped, mirroring the
  /// student side's point-recording guard.
  static func makePoints(
    logs: [StudentSetLog],
    familyByPlanExerciseID: [UUID: LiftFamily]
  ) -> [LiftFamily: [GrowthPoint]] {
    var grouped: [LiftFamily: [GrowthPoint]] = [:]
    for log in logs where log.completed {
      guard let family = familyByPlanExerciseID[log.planExerciseID] else { continue }
      let weight = NSDecimalNumber(decimal: log.weightKg).doubleValue
      let rpe = log.effectiveRPE.map { NSDecimalNumber(decimal: $0).doubleValue }
      guard
        let e1RMKg = E1RMCalculator.calculate(weightKg: weight, reps: log.reps, rpe: rpe)
      else { continue }
      grouped[family, default: []].append(
        GrowthPoint(id: log.id, date: log.loggedAt, e1RMKg: e1RMKg)
      )
    }
    return grouped.mapValues { $0.sorted { $0.date < $1.date } }
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
