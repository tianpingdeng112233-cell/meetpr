import CoreModels
import Foundation

enum TriageSignal: Hashable, Sendable {
  case notTrained(daysMissed: Int)
  case awaitingReply
}

enum StudentTriageSignalCalculator {
  static let notTrainedLookbackDays = 7
  static let missedTrainingDayThreshold = 2
  private static let recentLogWindowDays = 3

  static func signals(
    plan: StudentPlanView?,
    logs: [StudentSetLog],
    feedback: [CoachFeedback],
    now: Date
  ) -> [TriageSignal] {
    signals(
      studentID: nil,
      plan: plan,
      logs: logs,
      feedback: feedback,
      now: now
    )
  }

  static func signals(
    studentID: UUID?,
    plan: StudentPlanView?,
    logs: [StudentSetLog],
    feedback: [CoachFeedback],
    now: Date
  ) -> [TriageSignal] {
    let scopedLogs = studentID.map { id in logs.filter { $0.studentID == id } } ?? logs
    let scopedFeedback =
      studentID.map { id in feedback.filter { $0.studentID == id } } ?? feedback
    var signals: [TriageSignal] = []
    let missedDays = missedTrainingDays(plan: plan, logs: scopedLogs, now: now)

    if missedDays >= missedTrainingDayThreshold {
      signals.append(.notTrained(daysMissed: missedDays))
    }
    if isAwaitingReply(logs: scopedLogs, feedback: scopedFeedback, now: now) {
      signals.append(.awaitingReply)
    }
    return signals
  }

  static func summaryText(for signals: [TriageSignal]) -> String {
    let missedDays = signals.compactMap { signal in
      if case .notTrained(let daysMissed) = signal { return daysMissed }
      return nil
    }.max()
    let awaitingReply = signals.contains(.awaitingReply)

    switch (missedDays, awaitingReply) {
    case (.some(let daysMissed), true):
      return CoachRosterStrings.triageMissedAwaitingReply(daysMissed)
    case (.some(let daysMissed), false):
      return CoachRosterStrings.triageMissed(daysMissed)
    case (.none, true):
      return CoachRosterStrings.triageNewRecord
    case (.none, false):
      return ""
    }
  }

  private static func missedTrainingDays(
    plan: StudentPlanView?,
    logs: [StudentSetLog],
    now: Date
  ) -> Int {
    guard let plan else { return 0 }
    let calendar = CoachFeatureCalendar.calendar
    let today = CoachFeatureCalendar.startOfDay(now, calendar: calendar)
    let windowStart =
      calendar.date(byAdding: .day, value: -notTrainedLookbackDays, to: today) ?? today

    return plan.days.filter { day in
      let dayStart = CoachFeatureCalendar.startOfDay(day.date, calendar: calendar)
      return !day.exercises.isEmpty
        && dayStart >= windowStart
        && dayStart < today
        && !hasCompletedLog(on: day.date, logs: logs, calendar: calendar)
    }.count
  }

  private static func hasCompletedLog(
    on date: Date,
    logs: [StudentSetLog],
    calendar: Calendar
  ) -> Bool {
    logs.contains { log in
      log.completed && CoachFeatureCalendar.isSameDay(log.loggedAt, date, calendar: calendar)
    }
  }

  private static func isAwaitingReply(
    logs: [StudentSetLog],
    feedback: [CoachFeedback],
    now: Date
  ) -> Bool {
    let latestLog = logs.filter(\.completed).map(\.loggedAt).max()
    let latestFeedback = feedback.map(\.postedAt).max()
    let recentStart =
      CoachFeatureCalendar.calendar.date(byAdding: .day, value: -recentLogWindowDays, to: now)
      ?? now
    let hasRecentLog = latestLog.map { $0 >= recentStart && $0 <= now } ?? false
    let hasNewFeedback =
      latestLog.flatMap { logDate in
        latestFeedback.map { feedbackDate in feedbackDate >= logDate }
      } ?? false

    return hasRecentLog && !hasNewFeedback
  }
}
