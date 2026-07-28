import CoreModels
import Testing

@testable import StudentKit

@Test func studentDemoSeedIsWellFormed() {
  let plan = StudentDemoSeed.makePlanView()
  let feedback = StudentDemoSeed.makeFeedback()
  let logs = StudentDemoSeed.makeHistoricalLogs()

  #expect(plan.days.count == 7)
  #expect(plan.days.contains { !$0.exercises.isEmpty })
  #expect(feedback.contains { $0.readAt == nil })
  #expect(feedback.contains { $0.readAt != nil })
  #expect(feedback.contains { $0.planExerciseID != nil })
  #expect(!logs.isEmpty)
  #expect(logs.allSatisfy { $0.studentID == StudentDemoSeed.studentID })
}

@Test func demoStudentKeepsSquatBenchDeadliftE1RMThroughCompetitionGate() throws {
  let plan = StudentDemoSeed.makePlanView()
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  let resolved = Dictionary(
    plan.days.flatMap(\.exercises).compactMap { slot in
      resolveCompetitionFamily(exercise: slot.exercise, onboarding: profile)
        .map { ($0, slot.exercise.id) }
    },
    uniquingKeysWith: { first, _ in first }
  )
  let histories = StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID)

  #expect(Set(resolved.keys) == [.squat, .bench, .deadlift])
  #expect(
    Set(
      histories.compactMap { point in
        resolved.first(where: { $0.value == point.exerciseId })?.key
      }) == [.squat, .bench, .deadlift]
  )
  let squatExerciseID = try #require(resolved[.squat])
  let latestSquat =
    histories
    .filter { $0.exerciseId == squatExerciseID }
    .max { $0.computedAt < $1.computedAt }
  #expect(latestSquat?.sourceWeightKg == 142.5)
}

@Test func growthFormingDemoHasOneEligibleSetAndOneHistoryPoint() {
  let plan = StudentDemoSeed.makePlanView()
  let logs = StudentDemoSeed.makeSingleSessionLogs(plan: plan)
  let history = StudentDemoSeed.makeFormingE1RMHistory()

  #expect(logs.count == 1)
  #expect(logs.first?.completed == true)
  #expect(GrowthScreenPresentation.historyStats(logs: logs).trainingSessionCount == 1)
  #expect(history.count == 1)
  #expect(history.first?.exerciseId == logs.first?.exerciseID)
}
