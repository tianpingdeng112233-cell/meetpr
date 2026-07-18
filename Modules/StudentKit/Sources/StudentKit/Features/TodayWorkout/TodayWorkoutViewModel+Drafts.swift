import CoreModels
import Foundation
import RepositoryContracts

// MARK: - Draft building & e1RM/PR side effects

@available(iOS 17.0, macOS 14.0, *)
extension TodayWorkoutViewModel {
  func exerciseReferences(
    for day: StudentPlanDay,
    studentID: UUID
  ) async throws -> [UUID: ExerciseReference] {
    let familyByExercise = Dictionary(
      day.exercises.map {
        (
          $0.exercise.id,
          resolveCompetitionFamily(exercise: $0.exercise, onboarding: currentOnboarding)
        )
      },
      uniquingKeysWith: { first, _ in first })
    let exerciseIDs = Set(day.exercises.map(\.exercise.id))
    let e1rmRepo = self.e1rmRepo
    return try await withThrowingTaskGroup(of: (UUID, ExerciseReference?).self) { group in
      for exerciseID in exerciseIDs {
        let family = familyByExercise[exerciseID].flatMap { $0 }
        group.addTask {
          let points = try await e1rmRepo.fetchHistory(studentId: studentID, exerciseId: exerciseID)
          // Last/Best keep raw semantics but only over eligible sets
          // (spec 050 §2) — an RPE-6 warm-up is no reference.
          let selected = lastAndBest(
            from: E1RMSeries.eligibleRaw(points: points, family: family))
          let reference = ExerciseReference(
            last: selected.last.map(ExerciseReferenceSet.init(point:)),
            best: selected.best.map(ExerciseReferenceSet.init(point:))
          )
          return (exerciseID, reference.hasValue ? reference : nil)
        }
      }

      var references: [UUID: ExerciseReference] = [:]
      for try await (exerciseID, reference) in group {
        if let reference {
          references[exerciseID] = reference
        }
      }
      return references
    }
  }

  static func makeDrafts(
    for day: StudentPlanDay,
    existingLogs: [StudentSetLog]
  ) -> [SetRowDraft] {
    day.exercises.flatMap { exercise in
      exercise.prescribedSets.map { set in
        makeDraft(exercise: exercise, set: set, existingLogs: existingLogs)
      }
    }
  }

  static func makeDraft(
    exercise: StudentPlanExercise,
    set: PrescribedSet,
    existingLogs: [StudentSetLog]
  ) -> SetRowDraft {
    let existingLog = existingLogs.first {
      $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex
    }
    return SetRowDraft(
      id: set.id,
      planExerciseID: exercise.id,
      exerciseID: exercise.exercise.id,
      exerciseName: exercise.exercise.name,
      prescribed: set,
      actualWeight: existingLog?.weightKg ?? set.weightKg,
      actualReps: existingLog?.reps ?? set.reps,
      actualRPE: existingLog?.rpe ?? set.rpe ?? 8,
      completed: existingLog?.completed ?? false,
      failed: existingLog?.failed ?? false,
      loggedSetID: existingLog?.id
    )
  }

  func recordE1RMPoint(
    for draft: SetRowDraft,
    log: StudentSetLog,
    studentID: UUID
  ) async {
    // Shared pipeline (spec 050 §3): eligibility gate + noise-banded PR.
    let recorder = E1RMRecorder(e1rm: e1rmRepo, now: now)
    let event = await recorder.record(
      E1RMRecorder.Input(
        studentID: studentID,
        exerciseID: draft.exerciseID,
        family: exerciseFamily(planExerciseID: draft.planExerciseID),
        setLogID: log.id,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: draft.actualRPE,
        failed: log.failed
      ))
    if let event {
      pendingPRBanner = event
    }
  }

  private func exerciseFamily(planExerciseID: UUID) -> LiftFamily? {
    let day: StudentPlanDay?
    switch state {
    case .loaded(let plan, _), .recording(let plan, _, _):
      day = plan
    default:
      day = nil
    }
    guard let exercise = day?.exercises.first(where: { $0.id == planExerciseID })?.exercise
    else { return nil }
    return resolveCompetitionFamily(exercise: exercise, onboarding: currentOnboarding)
  }
}
