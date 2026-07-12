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

@Test func demoStudentKeepsSquatBenchDeadliftE1RMThroughCompetitionGate() {
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
}
