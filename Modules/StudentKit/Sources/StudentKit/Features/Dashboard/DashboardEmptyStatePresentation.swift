import CoreModels
import Foundation

struct DashboardPendingFeedbackPresentation: Equatable, Sendable {
  let completedSetCount: Int
  let submittedAt: Date
  let expectedResponseHours: Int?
}

struct DashboardRestDayPreview: Equatable, Sendable {
  let dateLabel: String
  let title: String
  let exerciseCount: Int
  let setCount: Int
  let estimatedMinutes: Int

  var farewellText: String {
    dateLabel == StudentStrings.localized(.dashboardEmptyStatePresentation001)
      ? StudentStrings.localized(.dashboardEmptyStatePresentation002)
      : StudentStrings.replacing(.dashboardEmptyStatePresentation003, values: ["\(dateLabel)"])
  }
}

struct DashboardWeekSummary: Equatable, Sendable {
  let completedTrainingDays: Int
  let totalTrainingDays: Int
  let totalVolumeKg: Decimal
  let newPRCount: Int
}

extension DashboardTodayPresentation {
  /// Design source:
  /// `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
  /// scene 01, "点评在路上".
  static func pendingFeedback(
    for day: StudentPlanDay?,
    logs: [StudentSetLog],
    feedbackItems: [CoachFeedback],
    now: Date,
    selectedCalendar: Calendar
  ) -> DashboardPendingFeedbackPresentation? {
    guard
      let day,
      !day.exercises.isEmpty,
      PlanCalendarDayIdentity.matches(
        planDate: day.scheduledDate,
        selectedDate: now,
        selectedCalendar: selectedCalendar
      )
    else {
      return nil
    }
    let exerciseIDs = Set(day.exercises.map(\.id))
    let expectedSets = expectedSetKeys(for: day)
    let completedLogs = logs.filter { log in
      log.completed
        && expectedSets.contains(
          DashboardPlanSetKey(
            planExerciseID: log.planExerciseID,
            setIndex: log.setIndex
          )
        )
    }
    let completedSets = Set(
      completedLogs.map {
        DashboardPlanSetKey(
          planExerciseID: $0.planExerciseID,
          setIndex: $0.setIndex
        )
      }
    )
    guard !expectedSets.isEmpty,
      completedSets == expectedSets,
      let submittedAt = completedLogs.map(\.loggedAt).max(),
      !hasFeedback(
        for: day,
        exerciseIDs: exerciseIDs,
        in: feedbackItems
      )
    else {
      return nil
    }
    return DashboardPendingFeedbackPresentation(
      completedSetCount: completedSets.count,
      submittedAt: submittedAt,
      expectedResponseHours: typicalResponseHours(from: feedbackItems)
    )
  }

  private static func expectedSetKeys(
    for day: StudentPlanDay
  ) -> Set<DashboardPlanSetKey> {
    Set(
      day.exercises.flatMap { exercise in
        exercise.prescribedSets.map {
          DashboardPlanSetKey(
            planExerciseID: exercise.id,
            setIndex: $0.setIndex
          )
        }
      }
    )
  }

  /// Design source:
  /// `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
  /// scene 06, rest-day recovery preview.
  static func restDayPreview(
    after date: Date,
    days: [StudentPlanDay],
    planStartDate: Date?,
    fallbackWeekIndex: Int?,
    selectedCalendar: Calendar
  ) -> DashboardRestDayPreview? {
    guard
      let nextTraining =
        days
        .filter({ !$0.exercises.isEmpty })
        .compactMap({ futureTraining($0, after: date, calendar: selectedCalendar) })
        .min(by: { $0.offset < $1.offset })
    else {
      return nil
    }
    return restDayPreview(
      nextTraining: nextTraining,
      planStartDate: planStartDate,
      fallbackWeekIndex: fallbackWeekIndex,
      selectedCalendar: selectedCalendar
    )
  }

  static func isAwaitingNextPlan(
    planEndDate: Date?,
    cycleDays: [StudentPlanDay],
    now: Date,
    selectedCalendar: Calendar
  ) -> Bool {
    guard
      let planEndDate,
      let endOffset = PlanCalendarDayIdentity.dayOffset(
        fromPlanDate: planEndDate,
        toSelectedDate: now,
        selectedCalendar: selectedCalendar
      ),
      endOffset >= 0
    else {
      return false
    }
    return !cycleDays.contains {
      guard
        let dayOffset = PlanCalendarDayIdentity.dayOffset(
          fromPlanDate: $0.date,
          toSelectedDate: now,
          selectedCalendar: selectedCalendar
        )
      else {
        return false
      }
      return dayOffset < 0
    }
  }

  /// Design source:
  /// `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
  /// scene 04, "本周小结".
  static func weekSummary(
    days: [StudentPlanDay],
    logs: [StudentSetLog],
    newPRCount: Int
  ) -> DashboardWeekSummary {
    let trainingDays = days.filter { !$0.exercises.isEmpty }
    let completedTrainingDays = trainingDays.filter {
      TrainingDayProgress(day: $0, logs: logs).state == .complete
    }.count
    let volume =
      logs
      .filter(\.completed)
      .reduce(Decimal.zero) { partial, log in
        partial + log.weightKg * Decimal(log.reps)
      }
    return DashboardWeekSummary(
      completedTrainingDays: completedTrainingDays,
      totalTrainingDays: trainingDays.count,
      totalVolumeKg: volume,
      newPRCount: newPRCount
    )
  }

  private static func hasFeedback(
    for day: StudentPlanDay,
    exerciseIDs: Set<UUID>,
    in feedbackItems: [CoachFeedback]
  ) -> Bool {
    feedbackItems.contains { feedback in
      if let planExerciseID = feedback.planExerciseID,
        exerciseIDs.contains(planExerciseID)
      {
        return true
      }
      guard let feedbackDate = feedback.dayDate else { return false }
      return PlanCalendarDayIdentity.isSameUTCDate(feedbackDate, day.scheduledDate)
    }
  }

  private static func futureTraining(
    _ day: StudentPlanDay,
    after date: Date,
    calendar: Calendar
  ) -> (offset: Int, day: StudentPlanDay)? {
    guard
      let offset = PlanCalendarDayIdentity.dayOffset(
        fromPlanDate: day.scheduledDate,
        toSelectedDate: date,
        selectedCalendar: calendar
      ),
      offset < 0
    else {
      return nil
    }
    return (-offset, day)
  }

  private static func restDayPreview(
    nextTraining: (offset: Int, day: StudentPlanDay),
    planStartDate: Date?,
    fallbackWeekIndex: Int?,
    selectedCalendar: Calendar
  ) -> DashboardRestDayPreview {
    let nextDay = nextTraining.day
    let families = MainLiftExerciseFamilyResolver.families(in: nextDay)
    let dayName =
      families.first.map {
        StudentStrings.replacing(
          .dashboardEmptyStatePresentation004, values: ["\($0.studentDisplayName)"])
      }
      ?? nextDay.exercises.first.map {
        StudentStrings.replacing(
          .dashboardEmptyStatePresentation004,
          values: ["\(StudentExerciseName.display($0.exercise))"]
        )
      }
      ?? StudentStrings.localized(.dashboardEmptyStatePresentation005)
    let weekIndex = resolvedWeekIndex(
      for: nextDay.date,
      planStartDate: planStartDate,
      fallback: fallbackWeekIndex
    )
    let familyCode = families.map(liftLetter).joined()
    let weekCode = familyCode.isEmpty ? "W\(weekIndex)" : "W\(weekIndex)-\(familyCode)"
    let setCount = nextDay.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    let durationSeconds = nextDay.exercises.reduce(0) { total, exercise in
      total
        + exercise.prescribedSets.reduce(0) { subtotal, set in
          subtotal + (set.restSeconds ?? 180) + 60
        }
    }
    let estimatedMinutes = max(5, Int(ceil(Double(durationSeconds) / 300)) * 5)
    let datePrefix =
      nextTraining.offset == 1
      ? StudentStrings.localized(.dashboardEmptyStatePresentation001)
      : monthDayText(nextDay.date, calendar: PlanCalendarDayIdentity.utcCalendar)
    return DashboardRestDayPreview(
      dateLabel: datePrefix,
      title: "\(datePrefix) · \(dayName) \(weekCode)",
      exerciseCount: nextDay.exercises.count,
      setCount: setCount,
      estimatedMinutes: estimatedMinutes
    )
  }

  private static func resolvedWeekIndex(
    for date: Date,
    planStartDate: Date?,
    fallback: Int?
  ) -> Int {
    guard
      let planStartDate,
      let elapsedDays = PlanCalendarDayIdentity.dayOffset(
        fromPlanDate: planStartDate,
        toSelectedDate: date,
        selectedCalendar: PlanCalendarDayIdentity.utcCalendar
      )
    else {
      return fallback ?? 1
    }
    return max(1, elapsedDays / 7 + 1)
  }

  private static func typicalResponseHours(from feedbackItems: [CoachFeedback]) -> Int? {
    let samples = feedbackItems.compactMap { feedback -> Int? in
      guard
        let submittedAt = feedback.video?.loggedAt,
        feedback.postedAt >= submittedAt
      else {
        return nil
      }
      return max(
        1,
        Int(ceil(feedback.postedAt.timeIntervalSince(submittedAt) / 3_600))
      )
    }.sorted()
    guard !samples.isEmpty else { return nil }
    return samples[samples.count / 2]
  }
}

private struct DashboardPlanSetKey: Hashable {
  let planExerciseID: UUID
  let setIndex: Int
}
