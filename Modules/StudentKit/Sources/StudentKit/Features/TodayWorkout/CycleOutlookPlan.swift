import CoreModels
import Foundation

struct CycleOutlookPlan: Sendable, Identifiable {
  let id: UUID
  let name: String
  let totalWeeks: Int
  let scheduledWeeks: Int
  let currentWeek: Int?
  let rows: [CycleOutlookLift]

  var initialWeekIndex: Int { max(0, (currentWeek ?? 1) - 2) }
}

struct CycleOutlookLift: Identifiable, Sendable {
  let id: LiftFamily
  let cells: [CycleOutlookCell]
}

extension CycleOutlook {
  static let families: [LiftFamily] = [.squat, .bench, .deadlift]

  static func isAvailable(plan: StudentPlanView?, profile: OnboardingProfile?) -> Bool {
    guard let plan,
      plan.publishedAt != nil
        || plan.handoff?.plans.contains(where: { $0.id == plan.cycleID }) == true
    else { return false }
    return plan.days.flatMap(\.exercises).contains {
      resolveCompetitionFamily(exercise: $0.exercise, onboarding: profile) != nil
        && $0.prescribedSets.contains { $0.setType != .warmup }
    }
  }

  // SPEC data-source boundary: plan, metadata, profile, current estimates and actual logs.
  // swiftlint:disable:next function_parameter_count
  static func make(
    plan: StudentPlanView, catalog: [Exercise] = [], profile: OnboardingProfile?,
    e1RM: [UUID: Double], logs: [StudentSetLog], isPreview: Bool,
    currentWeek: Int?, locale: Locale = .current
  ) -> CycleOutlookPlan {
    let summary = plan.handoff?.plans.first { $0.id == plan.cycleID }
    // Legacy offline projections have no summary; retain their known weeks until refreshed.
    let total = max(1, summary?.weeks ?? plan.days.map(\.weekNumber).max() ?? 1)
    let metadata = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let rows = families.compactMap { family -> CycleOutlookLift? in
      let candidates = plan.days.sorted(by: StudentPlanSequence.precedes).flatMap { day in
        day.exercises.filter {
          resolveCompetitionFamily(
            exercise: metadata[$0.exercise.id] ?? $0.exercise, onboarding: profile) == family
        }.flatMap { exercise in
          exercise.prescribedSets.filter { $0.setType != .warmup }.map { set in
            Candidate(
              day: day, exercise: exercise, set: set,
              plan: prescription(
                set, exercise: exercise, family: family,
                profile: profile, e1RM: e1RM[exercise.exercise.id]))
          }
        }
      }
      guard !candidates.isEmpty else { return nil }
      let currentE1RM = candidates.compactMap { e1RM[$0.exercise.exercise.id] }.max()
      let planEstimate = estimate(candidates.map(\.plan))
      let anchor = currentE1RM ?? planEstimate
      let weeks = (1...total).map { week -> CycleOutlookWeek in
        guard plan.days.contains(where: { $0.weekNumber == week }) else {
          return .init(state: .unscheduled)
        }
        return selectWeek(
          week, candidates: candidates, logs: logs,
          isPreview: isPreview, anchor: anchor)
      }
      return CycleOutlookLift(
        id: family,
        cells: row(
          weeks: weeks, e1RM: currentE1RM,
          currentWeekIndex: isPreview ? -1 : (currentWeek ?? 0) - 1,
          unit: profile?.unitPreference ?? .kg, locale: locale, planEstimate: planEstimate))
    }
    return CycleOutlookPlan(
      id: plan.cycleID, name: summary?.name ?? "",
      totalWeeks: total,
      scheduledWeeks: Set(plan.days.map(\.weekNumber).filter { (1...total).contains($0) }).count,
      currentWeek: isPreview ? nil : currentWeek, rows: rows)
  }

  private struct Candidate {
    let day: StudentPlanDay
    let exercise: StudentPlanExercise
    let set: PrescribedSet
    let plan: CycleOutlookSet
  }

  private struct ActualCandidate {
    let candidate: Candidate
    let set: CycleOutlookSet
    let score: Double
  }

  private static func selectWeek(
    _ week: Int, candidates: [Candidate], logs: [StudentSetLog],
    isPreview: Bool, anchor: Double?
  ) -> CycleOutlookWeek {
    let planned = candidates.filter { $0.day.weekNumber == week }
    guard
      let best = planned.max(by: {
        (score($0.plan, load: load($0.plan, e1RM: anchor, oneRM: nil)) ?? -.infinity)
          < (score($1.plan, load: load($1.plan, e1RM: anchor, oneRM: nil)) ?? -.infinity)
      })
    else { return .init(state: .notTrained) }
    let done = !isPreview && planned.allSatisfy { $0.day.completedAt != nil }
    guard done else { return .init(state: .scheduled, plan: best.plan, dayID: best.day.id) }
    // Match by prescribed slot, including actual extra sets under the same planned exercise.
    let actuals = logs.compactMap { log -> ActualCandidate? in
      guard log.completed, !log.isWarmup, let weightKg = log.weightKg,
        let candidate = planned.first(where: {
          $0.exercise.id == log.planExerciseID && $0.set.setIndex == log.setIndex
        }) ?? planned.first(where: { $0.exercise.id == log.planExerciseID })
      else { return nil }
      let actual = CycleOutlookSet(
        weightKg: NSDecimalNumber(decimal: weightKg).doubleValue,
        reps: log.reps, rpe: log.rpe.map { NSDecimalNumber(decimal: $0).doubleValue })
      let value = score(
        actual, load: Load(weightKg: actual.weightKg, fixed: candidate.plan.weightKg != nil))
      return value.map { ActualCandidate(candidate: candidate, set: actual, score: $0) }
    }
    guard let actual = actuals.max(by: { $0.score < $1.score }) else {
      return .init(
        state: .scheduled, done: true, plan: best.plan, skipped: true, dayID: best.day.id)
    }
    return .init(
      state: .scheduled, done: true, plan: actual.candidate.plan,
      actual: actual.set, dayID: actual.candidate.day.id)
  }

  private static func prescription(
    _ set: PrescribedSet, exercise: StudentPlanExercise, family: LiftFamily,
    profile: OnboardingProfile?, e1RM: Double?
  ) -> CycleOutlookSet {
    var value = CycleOutlookSet(
      weightKg: set.weightKg.map { NSDecimalNumber(decimal: $0).doubleValue },
      reps: set.repsMax ?? set.reps ?? 0, minimumReps: set.reps)
    switch set.intensity {
    case .rpe(let rpe), .rpeRange(_, let rpe):
      value.rpe = NSDecimalNumber(decimal: rpe).doubleValue
    case .weightRange(_, let upper): value.weightKg = NSDecimalNumber(decimal: upper).doubleValue
    case .percentage(let pct):
      value.pct = NSDecimalNumber(decimal: pct).doubleValue
      value.allowsRPEEstimate = false
      let resolved = PctAnchorResolver.resolve(
        .init(
          percentage: pct, anchor: set.effectivePercentageAnchor, exerciseFamily: family,
          registeredOneRMKg: profile?.registeredOneRMKg(for: family), currentE1RMKg: e1RM,
          exerciseID: exercise.exercise.id, planExerciseSortOrder: exercise.sequenceIndex,
          sameDaySets: []))
      value.resolvedPctKg = resolved.resolvedKg.map { NSDecimalNumber(decimal: $0).doubleValue }
    case .rir(let rir): value.rpe = 10 - Double(rir)
    case nil: break
    }
    return value
  }
}
