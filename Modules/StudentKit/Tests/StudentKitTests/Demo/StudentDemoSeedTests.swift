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
