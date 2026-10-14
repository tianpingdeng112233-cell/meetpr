import CoreModels
import Foundation
import RepositoryContracts

enum StudentAddedHistory {
  static func family(_ log: StudentAddedSetLog, catalog: [Exercise]) -> LiftFamily? {
    catalog.first { $0.id == log.exerciseID }?.mainLiftFamily
  }

  static func extraIndices(exercise: StudentPlanExercise, logs: [StudentSetLog]) -> [Int] {
    logs.filter { $0.planExerciseID == exercise.id && $0.setIndex >= exercise.prescribedSets.count }
      .map(\.setIndex).sorted()
  }

  static func record(
    _ logs: [StudentAddedSetLog], catalog: [Exercise], e1rm: any E1RMRepository,
    profile: OnboardingProfile?
  ) async {
    for log in logs.sorted(by: { $0.loggedAt < $1.loggedAt }) where !log.assumed {
      guard let family = family(log, catalog: catalog) else { continue }
      _ = await E1RMRecorder(e1rm: e1rm, now: { log.loggedAt }).record(
        E1RMRecorder.Input(
          studentID: log.studentID, exerciseID: log.exerciseID, family: family,
          setLogID: log.id, weightKg: log.weightKg, reps: log.reps, rpe: log.rpe,
          coachRPE: log.coachRPE, completed: log.completed, failed: log.failed,
          registeredOneRMKg: profile?.registeredOneRMKg(for: family)))
    }
  }
}

extension StudentAddedHistory {
  static func recordPlanned(
    _ logs: [StudentSetLog], days: [StudentPlanDay], catalog: [Exercise],
    e1rm: any E1RMRepository, profile: OnboardingProfile?
  ) async {
    let slots = Dictionary(
      days.flatMap(\.exercises).map { ($0.id, $0.exercise) },
      uniquingKeysWith: { first, _ in first })
    for log in logs.sorted(by: { $0.loggedAt < $1.loggedAt }) where !log.assumed {
      let exercise =
        log.exerciseID.flatMap { id in catalog.first { $0.id == id } } ?? slots[log.planExerciseID]
      guard let exercise,
        let family = resolveCompetitionFamily(exercise: exercise, onboarding: profile)
      else { continue }
      _ = await E1RMRecorder(e1rm: e1rm, now: { log.loggedAt }).record(
        E1RMRecorder.Input(
          studentID: log.studentID, exerciseID: exercise.id, family: family,
          setLogID: log.id, weightKg: log.weightKg, reps: log.reps, rpe: log.rpe,
          coachRPE: log.coachRPE, completed: log.completed, failed: log.failed,
          registeredOneRMKg: profile?.registeredOneRMKg(for: family)))
    }
  }
}
