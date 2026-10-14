import CoreModels
import Foundation
import RepositoryContracts

/// Deletes one source's derived records with the repository's revision guard, preserving other students.
enum StudentAddedDerivedHistory {
  static func remove(
    setID: UUID, studentID: UUID, exerciseIDs: [UUID], repository: any E1RMRepository,
    replacementBaselines: [E1RMWeightBaseline] = []
  ) async throws {
    for _ in 0..<3 {
      var ids = Set(exerciseIDs)
      for family in LiftFamily.allCases {
        ids.formUnion(
          try await repository.fetchHistory(studentId: studentID, family: family).map(\.exerciseId))
      }
      let snapshot = try await repository.historySnapshot(
        studentId: studentID, exerciseIds: Array(ids))
      let points = snapshot.history.values.flatMap { $0 }.filter { $0.setLogId != setID }
      let events = try await repository.prEvents(studentId: studentID, since: .distantPast)
        .filter { $0.setLogId != setID }
      let storedBaselines = try await repository.fetchWeightBaselines(studentId: studentID)
      let baselines = storedBaselines.compactMap { baseline in
        guard baseline.setLogId == setID else { return baseline }
        return replacementBaselines.filter { $0.family == baseline.family && $0.setLogId != setID }
          .max { $0.maxWeightKg < $1.maxWeightKg }
      }
      if try await repository.replaceHistory(
        studentId: studentID, with: points,
        weightBaselines: baselines, prEvents: events, ifUnchangedSince: snapshot.revision)
      {
        return
      }
    }
    throw RepairError.concurrentModification
  }

  enum RepairError: Error { case concurrentModification }

  static func baselines(
    _ records: StudentWorkoutLogs, days: [StudentPlanDay], catalog: [Exercise],
    profile: OnboardingProfile? = nil
  ) -> [E1RMWeightBaseline] {
    let slots = Dictionary(
      days.flatMap(\.exercises).map { ($0.id, $0.exercise) },
      uniquingKeysWith: { first, _ in first })
    let planned = records.planned.compactMap { log -> E1RMWeightBaseline? in
      let exercise =
        log.exerciseID.flatMap { id in catalog.first { $0.id == id } } ?? slots[log.planExerciseID]
      guard log.completed, !log.failed, !log.assumed, log.weightKg > 0, log.reps > 0,
        let exercise, let family = resolveCompetitionFamily(exercise: exercise, onboarding: profile)
      else { return nil }
      return E1RMWeightBaseline(
        studentId: log.studentID, family: family,
        maxWeightKg: NSDecimalNumber(decimal: log.weightKg).doubleValue,
        setLogId: log.id, achievedAt: log.loggedAt)
    }
    let added = records.added.compactMap { log -> E1RMWeightBaseline? in
      guard log.completed, !log.failed, !log.assumed, log.weightKg > 0, log.reps > 0,
        let family = StudentAddedHistory.family(log, catalog: catalog)
      else { return nil }
      return E1RMWeightBaseline(
        studentId: log.studentID, family: family,
        maxWeightKg: NSDecimalNumber(decimal: log.weightKg).doubleValue,
        setLogId: log.id, achievedAt: log.loggedAt)
    }
    return planned + added
  }
}
