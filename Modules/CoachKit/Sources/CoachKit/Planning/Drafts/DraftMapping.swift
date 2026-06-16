import CoreModels
import Foundation

@MainActor
public func toDomain(_ draft: DraftTrainingPlan) -> TrainingPlan {
  TrainingPlan(
    id: draft.id,
    coachID: draft.coachID,
    traineeID: draft.traineeID,
    name: draft.name,
    startDate: draft.startDate,
    endDate: draft.endDate,
    planWeeks: draft.planWeeks,
    source: .coach,
    status: .draft,
    createdAt: draft.lastSavedAt,
    updatedAt: draft.lastSavedAt
  )
}

@MainActor
public func toDomainDays(_ draft: DraftTrainingPlan) -> [PlanDay] {
  draft.draftDays
    .sorted { lhs, rhs in
      if lhs.weekNumber == rhs.weekNumber {
        lhs.sortOrder < rhs.sortOrder
      } else {
        lhs.weekNumber < rhs.weekNumber
      }
    }
    .map { day in
      PlanDay(
        id: day.id,
        planID: draft.id,
        dayOfWeek: day.dayOfWeek,
        weekNumber: day.weekNumber,
        sortOrder: day.sortOrder
      )
    }
}

@MainActor
public func toDomainExercises(_ draft: DraftTrainingPlan) -> [PlanExercise] {
  draft.draftDays
    .sorted { $0.sortOrder < $1.sortOrder }
    .flatMap { day in
      day.draftExercises
        .sorted { $0.sortOrder < $1.sortOrder }
        .map { exercise in
          PlanExercise(
            id: exercise.id,
            planDayID: day.id,
            exerciseID: exercise.exerciseID,
            isMainLift: exercise.isMainLift,
            sortOrder: exercise.sortOrder,
            notes: exercise.notes
          )
        }
    }
}

@MainActor
public func toDomainSets(_ draft: DraftTrainingPlan) -> [PlanSet] {
  draft.draftDays
    .sorted { $0.sortOrder < $1.sortOrder }
    .flatMap { day in
      day.draftExercises
        .sorted { $0.sortOrder < $1.sortOrder }
        .flatMap { exercise -> [PlanSet] in
          guard let setSpec = decodeSetSpec(exercise.setsData) else { return [] }
          return (1...setSpec.setCount).map { setNumber in
            let restSeconds = restSeconds(for: setSpec, setNumber: setNumber)
            return PlanSet(
              id: UUID(),
              planExerciseID: exercise.id,
              setNumber: setNumber,
              targetReps: setSpec.targetReps,
              targetRepsMax: setSpec.targetRepsMax,
              intensityMode: setSpec.intensityMode,
              targetValue: setSpec.targetValue,
              setType: setSpec.setType,
              restSeconds: restSeconds,
              createdAt: draft.lastSavedAt
            )
          }
        }
    }
}

private func restSeconds(for spec: DraftSetSpec, setNumber: Int) -> Int {
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

public func encodeSetSpec(_ spec: DraftSetSpec) throws -> Data {
  try MeetPRCodec.encoder.encode(spec)
}

public func decodeSetSpec(_ data: Data?) -> DraftSetSpec? {
  guard let data else { return nil }
  return try? MeetPRCodec.decoder.decode(DraftSetSpec.self, from: data)
}

public func encodeRules(_ rules: [DraftProgressionRule]) throws -> Data {
  try MeetPRCodec.encoder.encode(rules)
}

public func decodeRules(_ data: Data?) -> [DraftProgressionRule] {
  guard let data else { return [] }
  return (try? MeetPRCodec.decoder.decode([DraftProgressionRule].self, from: data)) ?? []
}

@MainActor
public func fromDomain(
  plan: TrainingPlan,
  days: [PlanDay],
  exercises: [PlanExercise],
  currentStep: PlanningStep = .selectStudent
) -> DraftTrainingPlan {
  let draft = DraftTrainingPlan(
    id: plan.id,
    traineeID: plan.traineeID,
    coachID: plan.coachID,
    name: plan.name,
    startDate: plan.startDate,
    endDate: plan.endDate,
    planWeeks: plan.planWeeks,
    currentStepRawValue: currentStep.rawValue,
    lastSavedAt: plan.updatedAt
  )

  let draftDays =
    days
    .sorted { $0.sortOrder < $1.sortOrder }
    .map { day -> DraftPlanDay in
      let draftDay = DraftPlanDay(
        id: day.id,
        dayOfWeek: day.dayOfWeek,
        weekNumber: day.weekNumber,
        sortOrder: day.sortOrder,
        plan: draft
      )
      draftDay.draftExercises =
        exercises
        .filter { $0.planDayID == day.id }
        .sorted { $0.sortOrder < $1.sortOrder }
        .map { exercise in
          DraftPlanExercise(
            id: exercise.id,
            exerciseID: exercise.exerciseID,
            isMainLift: exercise.isMainLift,
            sortOrder: exercise.sortOrder,
            notes: exercise.notes,
            day: draftDay
          )
        }
      return draftDay
    }

  draft.draftDays = draftDays
  return draft
}
