import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func assumedLogsDoNotChangeStudentStatisticsButRemainFetchable() async throws {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

  let plan = StudentDemoSeed.makePlanView()
  let day = plan.days[0]
  let exerciseID = day.exercises[0].id
  let realLog = importedStatisticsLog(
    exerciseID: exerciseID,
    setIndex: 0,
    loggedAt: day.date
  )
  let assumedLog = importedStatisticsLog(
    exerciseID: exerciseID,
    setIndex: 1,
    loggedAt: calendar.date(byAdding: .day, value: 1, to: day.date) ?? day.date,
    assumed: true
  )

  let baselineCount = StudentFormatting.completedCount(for: day, logs: [realLog])
  let withImportedCount = StudentFormatting.completedCount(
    for: day,
    logs: [realLog, assumedLog]
  )
  #expect(withImportedCount == baselineCount)

  let baselineSessions = TrainingHistoryView.completedSessionCount(
    logs: [realLog],
    calendar: calendar
  )
  let withImportedSessions = TrainingHistoryView.completedSessionCount(
    logs: [realLog, assumedLog],
    calendar: calendar
  )
  #expect(withImportedSessions == baselineSessions)

  let repository = InMemoryStudentTrainingLogRepository(seed: [realLog, assumedLog])
  let fetched = try await repository.fetchLogs(
    studentID: StudentDemoSeed.studentID,
    in: day.date...assumedLog.loggedAt
  )
  #expect(fetched.count == 2)
  #expect(fetched.contains { $0.id == assumedLog.id && $0.assumed })
}

private func importedStatisticsLog(
  exerciseID: UUID,
  setIndex: Int,
  loggedAt: Date,
  assumed: Bool = false
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: StudentDemoSeed.studentID,
    planExerciseID: exerciseID,
    setIndex: setIndex,
    loggedAt: loggedAt,
    weightKg: 100,
    reps: 5,
    rpe: 8,
    completed: true,
    assumed: assumed
  )
}
