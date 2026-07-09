import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func studentFormattingExcludesAssumedSetsButLogsRemainFetchable() async throws {
  let studentID = UUID()
  let day = StudentDemoSeed.makePlanView().days[0]
  let planExerciseID = try #require(day.exercises.first?.id)
  let timestamp = Date(timeIntervalSince1970: 1_783_468_800)
  let actual = statisticsLog(
    studentID: studentID, planExerciseID: planExerciseID, timestamp: timestamp, assumed: false)
  let assumed = statisticsLog(
    studentID: studentID, planExerciseID: planExerciseID, timestamp: timestamp, assumed: true)

  let counts = StudentFormatting.completedCount(for: day, logs: [actual, assumed])
  #expect(counts.completed == 1)

  let repository = InMemoryStudentTrainingLogRepository(seed: [assumed])
  let fetched = try await repository.fetchLogs(
    studentID: studentID,
    in: timestamp.addingTimeInterval(-1)...timestamp.addingTimeInterval(1),
    scope: .all
  )
  #expect(fetched.count == 1)
  #expect(fetched.first?.assumed == true)
}

@MainActor
@Test func growthSessionCountAndSoloMonthGroupingExcludeAssumedSets() {
  let timestamp = Date(timeIntervalSince1970: 1_783_468_800)
  let planExerciseID = UUID()
  let actual = statisticsLog(
    studentID: UUID(), planExerciseID: planExerciseID, timestamp: timestamp, assumed: false)
  let assumed = statisticsLog(
    studentID: actual.studentID, planExerciseID: planExerciseID,
    timestamp: timestamp.addingTimeInterval(-86_400), assumed: true)
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

  let sessionCount = TrainingHistoryView.completedSessionCount(
    logs: [actual, assumed],
    calendar: calendar
  )
  #expect(sessionCount == 1)
  // The history *list* still shows the assumed day (spec 053 §7: archival
  // display keeps imported records) — only the statistics exclude it.
  let months = TrainingHistoryViewModel.soloMonths(
    logs: [actual, assumed], names: [:], bestByDay: [:], calendar: calendar)
  #expect(months.reduce(0) { $0 + $1.days.count } == 2)
  let statCounts = TrainingHistoryViewModel.sessionDayCountByMonth(
    logs: [actual, assumed].filter { !$0.assumed }, calendar: calendar)
  #expect(statCounts.values.reduce(0, +) == 1)
}

private func statisticsLog(
  studentID: UUID,
  planExerciseID: UUID,
  timestamp: Date,
  assumed: Bool
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: studentID,
    planExerciseID: planExerciseID,
    loggedDate: timestamp.formatted(.iso8601.year().month().day()),
    assumed: assumed,
    setIndex: 0,
    loggedAt: timestamp,
    weightKg: 100,
    reps: 5,
    rpe: 8,
    completed: true
  )
}
