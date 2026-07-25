import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Test func notTrainedSignalStaysSilentBelowThreshold() {
  let signals = StudentTriageSignalCalculator.signals(
    plan: triagePlan(trainingOffsets: [1]),
    logs: [],
    feedback: [],
    now: triageDate(offset: 3)
  )

  #expect(signals.isEmpty)
}

@Test func notTrainedSignalFiresAtThreshold() {
  let signals = StudentTriageSignalCalculator.signals(
    plan: triagePlan(trainingOffsets: [1, 2]),
    logs: [],
    feedback: [],
    now: triageDate(offset: 3)
  )

  #expect(signals == [.notTrained(daysMissed: 2)])
}

@Test func notTrainedRosterStatusUsesDangerTone() {
  let row = StudentRosterRowModel(
    student: CoachStudentSummary(
      id: CoachStudentFeatureFixtures.studentID,
      displayName: "测试学员",
      status: .active
    ),
    plannedTrainingDays: 3,
    completedTrainingDays: 0,
    lastActiveAt: nil,
    triageSignals: [.notTrained(daysMissed: 2)]
  )

  #expect(row.statusTone == .notCompleted)
}

@Test func notTrainedSignalCountsMissesAboveThreshold() {
  let signals = StudentTriageSignalCalculator.signals(
    plan: triagePlan(trainingOffsets: [0, 1, 2]),
    logs: [],
    feedback: [],
    now: triageDate(offset: 3)
  )

  #expect(signals == [.notTrained(daysMissed: 3)])
}

@Test func notTrainedSignalIgnoresTodayAndCompletedDays() {
  let completedLogDate = triageDate(offset: 1, hour: 2)
  let completedLog = CoachStudentFeatureFixtures.log(loggedAt: completedLogDate)
  let signals = StudentTriageSignalCalculator.signals(
    plan: triagePlan(trainingOffsets: [1, 2, 3]),
    logs: [completedLog],
    feedback: [
      CoachStudentFeatureFixtures.feedback(postedAt: completedLogDate.addingTimeInterval(600))
    ],
    now: triageDate(offset: 3)
  )

  #expect(signals.isEmpty)
}

@Test func notTrainedSignalDoesNotCountShiftedOriginalDates() {
  let plan = StudentPlanView(
    cycleID: stableTriageUUID(80),
    weekIndex: 1,
    startDate: triageDate(offset: 0),
    days: [
      StudentPlanDay(
        id: stableTriageUUID(81),
        date: triageDate(offset: 0),
        shiftedToDate: triageDate(offset: 4),
        exercises: [CoachStudentFeatureFixtures.exercise()]
      ),
      StudentPlanDay(
        id: stableTriageUUID(82),
        date: triageDate(offset: 1),
        shiftedToDate: triageDate(offset: 5),
        exercises: [CoachStudentFeatureFixtures.exercise()]
      ),
    ]
  )

  let signals = StudentTriageSignalCalculator.signals(
    plan: plan,
    logs: [],
    feedback: [],
    now: triageDate(offset: 3)
  )

  #expect(signals.isEmpty)
}

@Test func awaitingReplySignalReusesRecentLogWithoutFeedbackRule() {
  let recentLog = CoachStudentFeatureFixtures.log(loggedAt: triageDate(offset: 2, hour: 1))
  let signals = StudentTriageSignalCalculator.signals(
    plan: nil,
    logs: [recentLog],
    feedback: [],
    now: triageDate(offset: 3)
  )

  #expect(signals == [.awaitingReply])
}

@Test func triageSignalsCanCoexistForOneStudent() {
  let recentLog = CoachStudentFeatureFixtures.log(loggedAt: triageDate(offset: 3, hour: 1))
  let signals = StudentTriageSignalCalculator.signals(
    plan: triagePlan(trainingOffsets: [1, 2]),
    logs: [recentLog],
    feedback: [],
    now: triageDate(offset: 3, hour: 2)
  )

  #expect(signals == [.notTrained(daysMissed: 2), .awaitingReply])
}

@Test func triageSignalsCanScopeLogsAndFeedbackToOneStudent() {
  let otherStudentID = CoachStudentFeatureFixtures.secondStudentID
  let signals = StudentTriageSignalCalculator.signals(
    studentID: CoachStudentFeatureFixtures.studentID,
    plan: triagePlan(trainingOffsets: [1, 2]),
    logs: [
      CoachStudentFeatureFixtures.log(
        studentID: otherStudentID,
        loggedAt: triageDate(offset: 1, hour: 1)
      ),
      CoachStudentFeatureFixtures.log(
        studentID: otherStudentID,
        loggedAt: triageDate(offset: 2, hour: 1)
      ),
    ],
    feedback: [
      CoachStudentFeatureFixtures.feedback(
        studentID: otherStudentID,
        postedAt: triageDate(offset: 2, hour: 2)
      )
    ],
    now: triageDate(offset: 3)
  )

  #expect(signals == [.notTrained(daysMissed: 2)])
}

@Test func noSignalWhenRecentLogAlreadyHasFeedback() {
  let logDate = triageDate(offset: 2, hour: 1)
  let signals = StudentTriageSignalCalculator.signals(
    plan: triagePlan(trainingOffsets: [3]),
    logs: [CoachStudentFeatureFixtures.log(loggedAt: logDate)],
    feedback: [CoachStudentFeatureFixtures.feedback(postedAt: triageDate(offset: 2, hour: 2))],
    now: triageDate(offset: 3)
  )

  #expect(signals.isEmpty)
}

private func triagePlan(trainingOffsets: Set<Int>) -> StudentPlanView {
  StudentPlanView(
    cycleID: stableTriageUUID(1),
    weekIndex: 1,
    startDate: CoachStudentFeatureFixtures.startDate,
    days: (0..<7).map { offset in
      StudentPlanDay(
        id: stableTriageUUID(UInt8(offset + 10)),
        date: triageDate(offset: offset),
        exercises: trainingOffsets.contains(offset) ? [CoachStudentFeatureFixtures.exercise()] : []
      )
    }
  )
}

private func triageDate(offset: Int, hour: Int = 0) -> Date {
  let calendar = CoachFeatureCalendar.calendar
  let components = DateComponents(day: offset, hour: hour)
  let fallback = CoachStudentFeatureFixtures.startDate.addingTimeInterval(
    Double(offset * 24 + hour) * 3_600)
  return calendar.date(byAdding: components, to: CoachStudentFeatureFixtures.startDate) ?? fallback
}

private func stableTriageUUID(_ byte: UInt8) -> UUID {
  UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, byte))
}
