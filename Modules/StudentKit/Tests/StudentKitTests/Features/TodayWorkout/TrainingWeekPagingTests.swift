import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct TrainingWeekPagingTests {
  @Test func defaultPageSelectsCursorAndKeepsCompletedWeeksAvailable() throws {
    let days = pagingDays()
    let page = TrainingSequenceLayout.page(days: days, selectedDayID: nil)

    #expect(page.weeks.map(\.weekNumber) == [1, 2, 4])
    #expect(page.currentWeekNumber == 2)
    let week = try #require(page.visibleWeek)
    #expect(week.weekNumber == 2)
    #expect(week.days.map(\.dayNumber) == [1, 2, 3])
    #expect(week.days.map(\.state) == [.completed, .current, .upcoming])
    #expect(week.days.map(\.isSelected) == [false, true, false])
    #expect(!page.showsBackToToday)
  }

  @Test func pagingSelectsFirstDayExceptWhenReturningToCursorWeek() throws {
    let days = pagingDays()
    let current = TrainingSequenceLayout.page(days: days, selectedDayID: nil)
    #expect(current.previousWeekSelection == days[0].id)
    #expect(current.nextWeekSelection == days[4].id)

    let past = TrainingSequenceLayout.page(days: days, selectedDayID: current.previousWeekSelection)
    #expect(past.visibleWeek?.weekNumber == 1)
    #expect(past.previousWeekSelection == nil)
    #expect(past.nextWeekSelection == days[2].id)
    #expect(past.showsBackToToday)

    let future = TrainingSequenceLayout.page(days: days, selectedDayID: current.nextWeekSelection)
    #expect(future.visibleWeek?.weekNumber == 4)
    #expect(future.nextWeekSelection == nil)
    #expect(future.previousWeekSelection == days[2].id)
    #expect(future.showsBackToToday)
    #expect(future.currentSelection == days[2].id)
  }

  @Test func selectingAnotherDayKeepsCursorMarkerAndWeekProgress() throws {
    let days = pagingDays()
    let page = TrainingSequenceLayout.page(days: days, selectedDayID: days[3].id)
    let week = try #require(page.visibleWeek)
    #expect(page.showsBackToToday)
    #expect(week.days.map(\.isSelected) == [false, false, true])
    #expect(week.days.map(\.state) == [.completed, .current, .upcoming])
    #expect(week.state == .current)
    #expect(week.completedCount == 1)
    #expect(page.weeks.first?.state == .completed)
    #expect(page.weeks.last?.state == .upcoming)
    #expect(page.showsWeekIndicators)
  }

  @Test func emptyCompletedAndReplacedPlansHaveSafeSelections() {
    let empty = TrainingSequenceLayout.page(days: [], selectedDayID: UUID())
    #expect(empty.visibleWeek == nil)
    #expect(empty.currentSelection == nil)
    #expect(empty.previousWeekSelection == nil && empty.nextWeekSelection == nil)
    #expect(!empty.showsBackToToday && !empty.showsWeekIndicators)

    let days = pagingDays()
    let replaced = TrainingSequenceLayout.page(days: days, selectedDayID: UUID())
    #expect(replaced.visibleWeek?.weekNumber == 2)
    #expect(!replaced.showsBackToToday)
    let completed = days.map { $0.replacingCompletion(completedAt: $0.date, source: "manual") }
    let final = TrainingSequenceLayout.page(days: completed, selectedDayID: nil)
    #expect(final.visibleWeek?.weekNumber == 4)
    #expect(final.visibleWeek?.state == .completed)
    #expect(final.currentSelection == days[4].id)
    #expect(final.nextWeekSelection == nil)
  }

  @Test func singleWeekHasNoArrowsAndLongPlansHideIndicators() {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let days = (1...9).map { week in
      StudentPlanDay(
        id: UUID(), weekNumber: week, dayOfWeek: 2, sortOrder: 0, date: date, exercises: [])
    }
    let single = TrainingSequenceLayout.page(days: [days[0]], selectedDayID: nil)
    #expect(single.previousWeekSelection == nil && single.nextWeekSelection == nil)
    #expect(single.showsWeekIndicators)
    #expect(
      TrainingSequenceLayout.page(days: Array(days.prefix(8)), selectedDayID: nil)
        .showsWeekIndicators)
    #expect(!TrainingSequenceLayout.page(days: days, selectedDayID: nil).showsWeekIndicators)
  }

  @Test func completingCursorMovesDefaultSelectionToNextWeek() {
    let days = pagingDays()
    let updated = days.map { day in
      day.weekNumber == 2 ? day.replacingCompletion(completedAt: day.date, source: "manual") : day
    }
    let page = TrainingSequenceLayout.page(days: updated, selectedDayID: nil)
    #expect(page.visibleWeek?.weekNumber == 4)
    #expect(page.currentSelection == days[4].id)
    #expect(!page.showsBackToToday)
  }

  private func pagingDays() -> [StudentPlanDay] {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    return [
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: 2, sortOrder: 0, date: date,
        completedAt: date, completionSource: "manual", exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 2, dayOfWeek: 2, sortOrder: 0, date: date,
        completedAt: date, completionSource: "manual", exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 2, dayOfWeek: 4, sortOrder: 0, date: date, exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 2, dayOfWeek: 6, sortOrder: 0, date: date, exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 4, dayOfWeek: 7, sortOrder: 0, date: date, exercises: []),
    ]
  }
}
