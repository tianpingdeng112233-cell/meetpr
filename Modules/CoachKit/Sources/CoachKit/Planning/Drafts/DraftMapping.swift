import CoreModels
import Foundation

public enum DraftMappingError: Error, Equatable, Sendable {
  case missingPlanID
  case missingDayID
}

@MainActor
public func toDomain(_ draft: DraftTrainingPlan) throws -> TrainingPlan {
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
public func toDomainDays(_ draft: DraftTrainingPlan) throws -> [PlanDay] {
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
public func toDomainExercises(_ draft: DraftTrainingPlan) throws -> [PlanExercise] {
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
