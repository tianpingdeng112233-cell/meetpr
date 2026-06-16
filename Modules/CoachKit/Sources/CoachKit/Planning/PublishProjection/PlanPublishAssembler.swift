import CoreModels
import Foundation

/// Materializes the W1-only draft into the full N-week plan tree that
/// `PlanRepository.publishPlan` (and the student projection) consume
/// (David 2026-06-14 — Step 8 publish). The editor only stores week 1; each
/// later week clones the day/exercise structure with `weekNumber = w` and a
/// set spec derived from the W1 spec + progression rules (same derivation the
/// Step 7 preview shows, so what the coach saw is what publishes).
@MainActor
enum PlanPublishAssembler {
  struct Assembled: Sendable {
    let plan: TrainingPlan
    let days: [PlanDay]
    let exercises: [PlanExercise]
    let sets: [PlanSet]
  }

  static func assemble(
    draft: DraftTrainingPlan,
    w1Specs: [UUID: DraftSetSpec],
    rules: [DraftProgressionRule],
    kind: PlanKind
  ) -> Assembled {
    let plan = makePlan(draft: draft, kind: kind)
    let templateDays = draft.draftDays.sorted { lhs, rhs in
      lhs.dayOfWeek == rhs.dayOfWeek
        ? lhs.sortOrder < rhs.sortOrder
        : lhs.dayOfWeek < rhs.dayOfWeek
    }

    let context = Context(
      planID: plan.id,
      createdAt: draft.lastSavedAt,
      w1Specs: w1Specs,
      rules: rules
    )
    var days: [PlanDay] = []
    var exercises: [PlanExercise] = []
    var sets: [PlanSet] = []

    for week in 1...max(1, draft.planWeeks) {
      for templateDay in templateDays {
        let materialized = materialize(templateDay: templateDay, week: week, context: context)
        days.append(materialized.day)
        exercises.append(contentsOf: materialized.exercises)
        sets.append(contentsOf: materialized.sets)
      }
    }

    return Assembled(plan: plan, days: days, exercises: exercises, sets: sets)
  }

  private struct Context {
    let planID: UUID
    let createdAt: Date
    let w1Specs: [UUID: DraftSetSpec]
    let rules: [DraftProgressionRule]
  }

  private static func makePlan(draft: DraftTrainingPlan, kind: PlanKind) -> TrainingPlan {
    TrainingPlan(
      id: draft.id,
      coachID: draft.coachID,
      traineeID: draft.traineeID,
      name: draft.name,
      startDate: draft.startDate,
      endDate: draft.endDate,
      planWeeks: draft.planWeeks,
      // Explicit kind so an adaptation week never publishes as regular and
      // trips the evaluation真 gate (the draft model carries no kind).
      kind: kind,
      source: .coach,
      status: .draft,
      createdAt: draft.lastSavedAt,
      updatedAt: draft.lastSavedAt
    )
  }

  private struct MaterializedDay {
    let day: PlanDay
    let exercises: [PlanExercise]
    let sets: [PlanSet]
  }

  private static func materialize(
    templateDay: DraftPlanDay,
    week: Int,
    context: Context
  ) -> MaterializedDay {
    let dayID = UUID()
    let day = PlanDay(
      id: dayID,
      planID: context.planID,
      dayOfWeek: templateDay.dayOfWeek,
      weekNumber: week,
      sortOrder: templateDay.sortOrder
    )

    var exercises: [PlanExercise] = []
    var sets: [PlanSet] = []
    let ordered = templateDay.draftExercises.sorted { $0.sortOrder < $1.sortOrder }
    for template in ordered {
      let exerciseID = UUID()
      exercises.append(
        PlanExercise(
          id: exerciseID,
          planDayID: dayID,
          exerciseID: template.exerciseID,
          isMainLift: template.isMainLift,
          sortOrder: template.sortOrder,
          notes: template.notes
        )
      )
      // Derive against the W1 draft-exercise id (rules key on it), then emit
      // the sets under this week's fresh exercise id.
      guard let weekOneSpec = context.w1Specs[template.id] else { continue }
      let spec = WeekDerivation.deriveSetSpec(
        forWeek: week,
        exerciseID: template.id,
        w1: weekOneSpec,
        rules: context.rules
      )
      for setNumber in 1...max(1, spec.setCount) {
        let restSeconds = restSeconds(for: spec, setNumber: setNumber)
        sets.append(
          PlanSet(
            id: UUID(),
            planExerciseID: exerciseID,
            setNumber: setNumber,
            targetReps: spec.targetReps,
            targetRepsMax: spec.targetRepsMax,
            intensityMode: spec.intensityMode,
            targetValue: spec.targetValue,
            setType: spec.setType,
            restSeconds: restSeconds,
            createdAt: context.createdAt
          )
        )
      }
    }

    return MaterializedDay(day: day, exercises: exercises, sets: sets)
  }

  private static func restSeconds(for spec: DraftSetSpec, setNumber: Int) -> Int {
    let perSetIndex = setNumber - 1
    if let restSecondsPerSet = spec.restSecondsPerSet,
      restSecondsPerSet.indices.contains(perSetIndex)
    {
      return restSecondsPerSet[perSetIndex]
    }
    if let restSeconds = spec.restSeconds {
      return restSeconds
    }
    return RestDefaults.seconds(forRPE: spec.intensityMode == .rpe ? spec.targetValue : nil)
  }
}
