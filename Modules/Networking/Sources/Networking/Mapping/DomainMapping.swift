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
      anchorWeekday: anchorWeekday,
      kind: kind,
      source: source,
      sourceTemplateID: sourceTemplateID,
      status: status,
      totalShiftDays: totalShiftDays,
      latestShiftCreatedAt: latestShiftCreatedAt,
      publishedAt: publishedAt,
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
      sortOrder: sortOrder,
      shiftedToDate: shiftedToDate,
      completedAt: completedAt,
      completionSource: completionSource
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
      loadMode: loadMode,
      targetPct: targetPct,
      targetRPE: targetRPE,
      rirTarget: rirTarget,
      rpeLow: rpeLow,
      rpeHigh: rpeHigh,
      weightLow: weightLow,
      weightHigh: weightHigh,
      targetWeight: targetWeight,
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
      setIndex: setIndex,
      loggedAt: loggedAt,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      coachRPE: coachRPE,
      completed: completed,
      failed: failed,
      assumed: assumed
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
      videoID: videoID,
      video: video?.toDomain(),
      text: text,
      postedAt: postedAt,
      readAt: readAt
    )
  }
}

extension FeedbackVideoDTO {
  public func toDomain() -> CoachFeedbackVideo {
    CoachFeedbackVideo(
      id: id,
      exerciseName: exerciseName,
      setIndex: setIndex,
      weightKg: weightKg,
      reps: reps,
      loggedAt: loggedAt
    )
  }
}

extension VideoMarkerDTO {
  public func toDomain() -> VideoMarker {
    VideoMarker(
      id: id,
      videoID: videoID,
      coachID: coachID,
      timeMilliseconds: timeMs,
      level: level,
      note: note,
      createdAt: createdAt,
      attachmentID: attachmentID,
      annotationURL: annotationURL,
      annotationExpiresIn: annotationExpiresIn
    )
  }
}
