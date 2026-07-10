import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct TrainingTabRedesignTests {
  private func utcCalendar(firstWeekday: Int = 2) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    calendar.firstWeekday = firstWeekday
    return calendar
  }

  private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    utcCalendar().date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
  }

  private func point(e1rm: Double, reps: Int, weight: Double, at date: Date) -> E1RMHistoryPoint {
    E1RMHistoryPoint(
      id: UUID(),
      studentId: UUID(),
      exerciseId: UUID(),
      setLogId: UUID(),
      computedAt: date,
      e1RMKg: e1rm,
      sourceWeightKg: weight,
      sourceReps: reps,
      sourceRPE: nil
    )
  }

  // MARK: - lastAndBest

  @Test func lastAndBestPicksMostRecentAndMaxE1RM() {
    let points = [
      point(e1rm: 150, reps: 5, weight: 130, at: day(2026, 6, 1)),
      point(e1rm: 170, reps: 3, weight: 160, at: day(2026, 6, 8)),
      point(e1rm: 160, reps: 5, weight: 140, at: day(2026, 6, 15)),
    ]
    let result = lastAndBest(from: points)
    #expect(result.last?.computedAt == day(2026, 6, 15))
    #expect(result.last?.sourceReps == 5)
    #expect(result.best?.e1RMKg == 170)
    #expect(result.best?.sourceWeightKg == 160)
  }

  @Test func lastAndBestEmptyIsNil() {
    let result = lastAndBest(from: [])
    #expect(result.last == nil)
    #expect(result.best == nil)
  }

  @Test func lastAndBestSinglePointIsBothLastAndBest() {
    let only = point(e1rm: 100, reps: 5, weight: 90, at: day(2026, 6, 1))
    let result = lastAndBest(from: [only])
    #expect(result.last?.e1RMKg == 100)
    #expect(result.best?.e1RMKg == 100)
  }

  // MARK: - Calendar layout

  @Test func weekDatesReturnsSevenAlignedToFirstWeekday() {
    let calendar = utcCalendar(firstWeekday: 2)
    let dates = TrainingCalendarLayout.weekDates(containing: day(2026, 6, 17), calendar: calendar)
    #expect(dates.count == 7)
    #expect(calendar.component(.weekday, from: dates[0]) == calendar.firstWeekday)
    #expect(dates.contains { calendar.isDate($0, inSameDayAs: day(2026, 6, 17)) })
  }

  @Test func monthDatesCoversWholeMonthInFullWeeks() {
    let calendar = utcCalendar(firstWeekday: 2)
    let dates = TrainingCalendarLayout.monthDates(containing: day(2026, 6, 17), calendar: calendar)
    #expect(dates.count % 7 == 0)
    #expect(dates.contains { calendar.isDate($0, inSameDayAs: day(2026, 6, 1)) })
    #expect(dates.contains { calendar.isDate($0, inSameDayAs: day(2026, 6, 30)) })
  }

  @Test func moveShiftsByWeekOrMonth() {
    let calendar = utcCalendar()
    let nextWeek = TrainingCalendarLayout.move(
      day(2026, 6, 17), mode: .week, by: 1, calendar: calendar)
    #expect(calendar.isDate(nextWeek, inSameDayAs: day(2026, 6, 24)))
    let prevMonth = TrainingCalendarLayout.move(
      day(2026, 6, 17), mode: .month, by: -1, calendar: calendar)
    #expect(calendar.isDate(prevMonth, inSameDayAs: day(2026, 5, 17)))
  }

  @Test func makeDaysFlagsSelectedTodayAndTrainingDay() {
    let calendar = utcCalendar(firstWeekday: 2)
    let trainingDate = day(2026, 6, 17)
    let planDay = StudentPlanDay(id: UUID(), date: trainingDate, exercises: [])
    let period = TrainingCalendarPeriod(
      displayedDate: trainingDate,
      selectedDate: trainingDate,
      today: trainingDate,
      mode: .week
    )
    let days = TrainingCalendarLayout.makeDays(
      period: period, cycleDays: [planDay], logs: [], calendar: calendar)
    let match = days.first { calendar.isDate($0.date, inSameDayAs: trainingDate) }
    #expect(match?.isSelected == true)
    #expect(match?.isToday == true)
    #expect(match?.planDay != nil)
    let nonTraining = days.first { !calendar.isDate($0.date, inSameDayAs: trainingDate) }
    #expect(nonTraining?.planDay == nil)
  }

  @Test func makeDaysPlacesShiftedTrainingOnlyOnEffectiveDate() {
    let calendar = utcCalendar(firstWeekday: 2)
    let scheduledDate = day(2026, 6, 17)
    let shiftedDate = day(2026, 6, 19)
    let planDay = StudentPlanDay(
      id: UUID(),
      date: scheduledDate,
      shiftedToDate: shiftedDate,
      exercises: []
    )
    let days = TrainingCalendarLayout.makeDays(
      period: TrainingCalendarPeriod(
        displayedDate: scheduledDate,
        selectedDate: scheduledDate,
        today: scheduledDate,
        mode: .week
      ),
      cycleDays: [planDay],
      logs: [],
      calendar: calendar
    )

    let original = days.first { calendar.isDate($0.date, inSameDayAs: scheduledDate) }
    let target = days.first { calendar.isDate($0.date, inSameDayAs: shiftedDate) }
    #expect(original?.planDay == nil)
    #expect(target?.planDay?.id == planDay.id)
  }
}
