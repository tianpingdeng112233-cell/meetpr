import CoreModels
import Foundation

public struct TrainingPlanTree: Codable, Equatable, Sendable {
  public let plan: TrainingPlan
  public let days: [PlanDay]
  public let exercises: [PlanExercise]
  public let sets: [PlanSet]

  public init(
    plan: TrainingPlan,
    days: [PlanDay],
    exercises: [PlanExercise],
    sets: [PlanSet]
  ) {
    self.plan = plan
    self.days = days
    self.exercises = exercises
    self.sets = sets
  }
}

extension PlanDTO {
  public func toDomain() -> TrainingPlan {
    TrainingPlan(
      id: id,
      coachID: coachID,
      traineeID: traineeID,
      name: name,
      startDate: startDate,
      endDate: endDate,
      planWeeks: planWeeks,
      kind: kind,
      source: source,
      sourceTemplateID: sourceTemplateID,
      status: status,
      blockType: blockType,
      mesocyclePhase: mesocyclePhase,
      trainingMax: trainingMax,
      tmSetAt: tmSetAt,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension PlanWithChildrenDTO {
  public func toDomain() -> TrainingPlanTree {
    let mappedDays = days.map { $0.toDomain() }
    let mappedExercises = days.flatMap(\.exercises).map { $0.toDomain() }
    let mappedSets = days.flatMap(\.exercises).flatMap(\.sets).map { $0.toDomain() }

    return TrainingPlanTree(
      plan: plan.toDomain(),
      days: mappedDays,
      exercises: mappedExercises,
      sets: mappedSets
    )
  }
}

extension PlanDayDTO {
  public func toDomain() -> PlanDay {
    PlanDay(
      id: id,
      planID: planID,
      dayOfWeek: dayOfWeek,
      weekNumber: weekNumber,
      sortOrder: sortOrder
    )
  }
}

extension PlanExerciseDTO {
  public func toDomain() -> PlanExercise {
    PlanExercise(
      id: id,
      planDayID: planDayID,
      exerciseID: exerciseID,
      isMainLift: isMainLift,
      sortOrder: sortOrder,
      notes: notes
    )
  }
}

extension PlanSetDTO {
  public func toDomain() -> PlanSet {
    PlanSet(
      id: id,
      planExerciseID: planExerciseID,
      setNumber: setNumber,
      targetReps: targetReps,
      targetRepsMax: targetRepsMax,
      intensityMode: intensityMode,
      targetValue: targetValue,
      setType: setType,
      restSeconds: restSeconds,
      coachNote: coachNote,
      createdAt: createdAt
    )
  }
}

extension SetLogDTO {
  public func toDomain() -> StudentSetLog {
    StudentSetLog(
      id: id,
      studentID: studentID,
      planExerciseID: planExerciseID,
      exerciseID: exerciseID,
      loggedDate: loggedDate,
      adhoc: adhoc,
      assumed: assumed,
      setIndex: setIndex,
      loggedAt: loggedAt,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      completed: completed,
      failed: failed
    )
  }
}

extension FeedbackDTO {
  public func toDomain() -> CoachFeedback {
    CoachFeedback(
      id: id,
      coachID: coachID,
      studentID: studentID,
      dayDate: dayDate,
      planExerciseID: planExerciseID,
      text: text,
      postedAt: postedAt,
      readAt: readAt
    )
  }
}
