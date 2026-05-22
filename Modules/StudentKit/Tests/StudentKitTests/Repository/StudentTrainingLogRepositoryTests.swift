import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func trainingLogRepositoryUpsertsByStudentExerciseAndSetIndex() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let exerciseID = plan.days[0].exercises[0].id
  let studentID = StudentDemoSeed.studentID
  let repository = InMemoryStudentTrainingLogRepository()

  let first = log(studentID: studentID, exerciseID: exerciseID, setIndex: 0, reps: 5)
  let overwrite = log(studentID: studentID, exerciseID: exerciseID, setIndex: 0, reps: 6)

  try await repository.recordSet(first)
  try await repository.recordSet(overwrite)

  let logs = try await repository.fetchLogsForExercise(
    studentID: studentID, planExerciseID: exerciseID)
  #expect(logs.count == 1)
  #expect(logs[0].reps == 6)
}

@Test func trainingLogRepositoryFiltersByRangeAndStudent() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let exerciseID = plan.days[0].exercises[0].id
  let studentID = StudentDemoSeed.studentID
  let otherStudentID = UUID()
  let repository = InMemoryStudentTrainingLogRepository()

  try await repository.recordSet(
    log(studentID: studentID, exerciseID: exerciseID, setIndex: 0, loggedAt: plan.days[0].date)
  )
  try await repository.recordSet(
    log(studentID: studentID, exerciseID: exerciseID, setIndex: 1, loggedAt: plan.days[3].date)
  )
  try await repository.recordSet(
    log(studentID: otherStudentID, exerciseID: exerciseID, setIndex: 0, loggedAt: plan.days[0].date)
  )

  let logs = try await repository.fetchLogs(
    studentID: studentID,
    in: plan.days[0].date...plan.days[0].date.addingTimeInterval(86_400 - 1)
  )

  #expect(logs.count == 1)
  #expect(logs[0].studentID == studentID)
  #expect(logs[0].setIndex == 0)
}

private func log(
  studentID: UUID,
  exerciseID: UUID,
  setIndex: Int,
  reps: Int = 5,
  loggedAt: Date = StudentDemoSeed.referenceDate
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: studentID,
    planExerciseID: exerciseID,
    setIndex: setIndex,
    loggedAt: loggedAt,
    weightKg: 100,
    reps: reps,
    rpe: 8,
    completed: true
  )
}
