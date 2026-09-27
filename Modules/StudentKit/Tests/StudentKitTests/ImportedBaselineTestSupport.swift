import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

struct ImportedBaselineFixture {
  private struct SetSample {
    let weight: Double
    let reps: Int
    let rpe: Double?

    init(_ weight: Double, _ reps: Int, _ rpe: Double?) {
      self.weight = weight
      self.reps = reps
      self.rpe = rpe
    }
  }

  let studentID = UUID()
  let exerciseID = UUID()
  let now: Date
  var logs: [StudentSetLog] = []
  var oldPoints: [E1RMHistoryPoint] = []

  init() throws {
    now = try Date("2026-09-27T12:00:00Z", strategy: .iso8601)

    for (day, sets) in Self.rows {
      let date = try Date(day + "T12:00:00Z", strategy: .iso8601)
      for (index, values) in sets.enumerated() {
        let weight = values.weight
        let reps = values.reps
        let rpe = values.rpe
        let id = UUID()
        let time = date.addingTimeInterval(Double(index))
        let assumed = day == "2026-07-10"
        logs.append(
          StudentSetLog(
            id: id, studentID: studentID, planExerciseID: UUID(), exerciseID: exerciseID,
            setIndex: index, loggedAt: time, loggedDate: day, weightKg: Decimal(weight),
            reps: reps, rpe: rpe.map { Decimal($0) }, completed: true, assumed: assumed
          ))
        guard reps <= 5 else { continue }
        oldPoints.append(
          E1RMHistoryPoint(
            id: UUID(), studentId: studentID, exerciseId: exerciseID, family: .deadlift,
            setLogId: id, computedAt: time,
            e1RMKg: try #require(E1RMCalculator.calculate(weightKg: weight, reps: reps, rpe: rpe)),
            sourceWeightKg: weight, sourceReps: reps, sourceRPE: rpe,
            confidence: assumed ? .normal : .low, origin: assumed ? .imported : .logged
          ))
      }
    }
  }

  private static let rows: [(String, [SetSample])] = [
    (
      "2026-07-10",
      [
        .init(130, 5, nil), .init(130, 5, nil), .init(115, 5, nil), .init(115, 5, nil),
        .init(130, 5, nil),
      ]
    ),
    (
      "2026-07-20",
      [
        .init(135, 5, 6), .init(135, 5, 6.5), .init(135, 5, 6.5), .init(135, 5, 6.5),
        .init(120, 5, 6),
      ]
    ),
    (
      "2026-07-27",
      [.init(140, 5, 6), .init(140, 5, 6), .init(125, 5, 6), .init(125, 5, 6), .init(140, 5, 6)]
    ),
    (
      "2026-08-05",
      [.init(145, 5, 6), .init(145, 5, 6), .init(145, 5, 6), .init(130, 5, 6), .init(130, 5, 6)]
    ),
    ("2026-08-16", [.init(100, 10, 6), .init(120, 10, 6)]),
    ("2026-08-24", [.init(145, 5, 7), .init(145, 5, 6), .init(145, 5, 7), .init(145, 5, 6)]),
    ("2026-09-03", [.init(150, 5, 7), .init(150, 5, 7), .init(150, 5, 7), .init(150, 5, 7)]),
    ("2026-09-15", [.init(155, 5, 6), .init(155, 5, 7), .init(155, 5, 7), .init(155, 5, 8)]),
    ("2026-09-23", [.init(160, 5, 7), .init(160, 5, 7.5), .init(160, 5, 8), .init(160, 5, 8)]),
  ]

  var profile: OnboardingProfile {
    OnboardingProfile(
      userId: studentID, deadliftStyle: .conventional, deadlift1RMKg: 210,
      createdAt: .distantPast, updatedAt: .distantPast)
  }

  var plans: CoachRPEPlanRepository {
    let exercise = Exercise(
      id: exerciseID, name: "Conventional deadlift", exerciseType: .mainLift,
      mainLiftFamily: .deadlift, isCompetitionLift: true, competitionStance: .conventional,
      muscleGroups: [], equipment: [], createdAt: .distantPast
    )
    let day = StudentPlanDay(
      id: UUID(), date: now,
      exercises: [
        StudentPlanExercise(id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: [])
      ])
    return CoachRPEPlanRepository(
      plan: StudentPlanView(
        cycleID: UUID(), weekIndex: 1, startDate: now, days: [day]
      ))
  }

  func reconciler(e1rm: any E1RMRepository) -> E1RMCoachRPEReconciler {
    E1RMCoachRPEReconciler(
      logs: InMemoryStudentTrainingLogRepository(seed: logs),
      onboarding: InMemoryOnboardingRepository(studentId: studentID, seed: profile),
      plans: plans, catalogReader: nil, e1rm: e1rm, now: { now }
    )
  }
}
