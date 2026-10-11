import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func spec085TodaySelectionMovesWithoutMovingCursorAndResets() throws {
  let now = Date()
  let first = StudentPlanDay(id: UUID(), weekNumber: 1, dayOfWeek: 1, date: now, exercises: [])
  let second = StudentPlanDay(id: UUID(), weekNumber: 1, dayOfWeek: 2, date: now, exercises: [])
  let days = [first, second]
  var selection = DashboardDaySelection()
  #expect(selection.day(in: days, now: now)?.id == first.id)
  selection.select(second.id)
  #expect(selection.day(in: days, now: now)?.id == second.id)
  let cells = DashboardTodayPresentation.progressSegments(days: days, selectedDayID: second.id)
  #expect(cells.map(\.isSelected) == [false, true])
  #expect(cells.map(\.state) == [.current, .upcoming])
  selection.reset()
  #expect(selection.day(in: days, now: now)?.id == first.id)
  let completed = first.replacingCompletion(completedAt: now, source: "manual")
  #expect(selection.day(in: [completed, second], now: now)?.id == completed.id)
}

@Test func spec085OverviewContainsOnlySelectedDaySummaryAndOrderedNames() {
  let date = Date()
  let squat = Exercise(
    id: UUID(), name: "深蹲", nameEn: "Squat", exerciseType: .mainLift,
    mainLiftFamily: .squat, isCompetitionLift: true, muscleGroups: [], equipment: [],
    createdAt: date)
  let press = Exercise(
    id: UUID(), name: "腿举", nameEn: "Leg press", exerciseType: .accessory,
    isCompetitionLift: false, muscleGroups: [], equipment: [], createdAt: date)
  let day = StudentPlanDay(
    id: UUID(), weekNumber: 1, dayOfWeek: 1, date: date,
    exercises: [
      StudentPlanExercise(
        id: UUID(), exercise: press, sequenceIndex: 1,
        prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0)]),
      StudentPlanExercise(
        id: UUID(), exercise: squat, sequenceIndex: 0,
        prescribedSets: [
          PrescribedSet(id: UUID(), setIndex: 0),
          PrescribedSet(id: UUID(), setIndex: 1),
        ]),
    ])
  let overview = DashboardSessionOverview(
    day: day, cursorID: day.id, locale: Locale(identifier: "en"))
  #expect(overview.dayID == day.id)
  #expect(overview.name == "Squat day")
  #expect(overview.status == .current)
  #expect(overview.summary == "2 exercises · 3 sets")
  #expect(overview.exerciseNames == "Squat · Leg press")
  #expect(DashboardSessionOverview(day: day, cursorID: UUID()).status == .upcoming)
  let completed = day.replacingCompletion(completedAt: date, source: "manual")
  #expect(DashboardSessionOverview(day: completed, cursorID: UUID()).status == .done)
}
