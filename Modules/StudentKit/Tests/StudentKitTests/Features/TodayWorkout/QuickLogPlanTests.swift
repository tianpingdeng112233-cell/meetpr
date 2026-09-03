import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Suite struct QuickLogPlanTests {
  private let studentID = UUID()
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }()

  @Test func editingOneCellChangesOnlyThatSet() {
    let fixture = makeFixture()
    var plan = makePlan(drafts: fixture.drafts)

    plan.updateWeight(147.5, for: fixture.drafts[1].id)

    let logs = plan.makeLogs(studentID: studentID)
    #expect(logs.map(\.weightKg) == [140, 147.5, 90, 90])
  }

  @Test func syncingWeightUpdatesEverySetInTheSameExerciseOnly() {
    let fixture = makeFixture()
    var plan = makePlan(drafts: fixture.drafts)
    plan.updateWeight(145, for: fixture.drafts[0].id)

    plan.syncWeightToExercise(from: fixture.drafts[0].id)

    let logs = plan.makeLogs(studentID: studentID)
    #expect(logs.map(\.weightKg) == [145, 145, 90, 90])
  }

  @Test func excludedRowsAreOmittedWithoutRenumberingSetIndexes() {
    let fixture = makeFixture()
    var plan = makePlan(drafts: fixture.drafts)

    plan.setIncluded(false, for: fixture.drafts[0].id)
    plan.setIncluded(false, for: fixture.drafts[2].id)
    plan.setIncluded(false, for: fixture.drafts[3].id)

    let logs = plan.makeLogs(studentID: studentID)
    #expect(logs.count == 1)
    #expect(logs.first?.planExerciseID == fixture.squatID)
    #expect(logs.first?.setIndex == 1)
  }

  @Test func selectedDateDerivesLocalNoonAndDateOnlyWireValue() throws {
    let fixture = makeFixture()
    let selected = date(year: 2026, month: 9, day: 1, hour: 19)
    let plan = QuickLogPlan(
      drafts: fixture.drafts,
      selectedDate: selected,
      allowedDateRange: date(year: 2026, month: 8, day: 30)...date(year: 2026, month: 9, day: 2),
      calendar: calendar
    )

    let log = try #require(plan.makeLogs(studentID: studentID).first)
    #expect(log.loggedAt == date(year: 2026, month: 9, day: 1, hour: 12))
    #expect(log.loggedDate == "2026-09-01")
  }

  @Test func selectedDateIsClampedToAllowedDays() {
    let fixture = makeFixture()
    var plan = QuickLogPlan(
      drafts: fixture.drafts,
      selectedDate: date(year: 2026, month: 8, day: 20),
      allowedDateRange: date(year: 2026, month: 8, day: 30)...date(year: 2026, month: 9, day: 2),
      calendar: calendar
    )
    #expect(plan.selectedDate == date(year: 2026, month: 8, day: 30))

    plan.selectDate(date(year: 2026, month: 9, day: 20))

    #expect(plan.selectedDate == date(year: 2026, month: 9, day: 2))
  }

  private func makePlan(drafts: [TodayWorkoutViewModel.SetRowDraft]) -> QuickLogPlan {
    QuickLogPlan(
      drafts: drafts,
      selectedDate: date(year: 2026, month: 9, day: 1),
      allowedDateRange: date(year: 2026, month: 8, day: 30)...date(year: 2026, month: 9, day: 2),
      calendar: calendar
    )
  }

  private func makeFixture() -> (
    drafts: [TodayWorkoutViewModel.SetRowDraft], squatID: UUID
  ) {
    let squat = planExercise(name: "Squat", weight: 140, sets: 2, sequenceIndex: 0)
    let bench = planExercise(name: "Bench", weight: 90, sets: 2, sequenceIndex: 1)
    let day = StudentPlanDay(id: UUID(), date: Date(), exercises: [squat, bench])
    return (
      TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []),
      squat.id
    )
  }

  private func planExercise(
    name: String,
    weight: Decimal,
    sets: Int,
    sequenceIndex: Int
  ) -> StudentPlanExercise {
    StudentPlanExercise(
      id: UUID(),
      exercise: Exercise(
        id: UUID(),
        name: name,
        exerciseType: .mainLift,
        isCompetitionLift: true,
        muscleGroups: [],
        equipment: [],
        createdAt: Date()
      ),
      sequenceIndex: sequenceIndex,
      prescribedSets: (0..<sets).map {
        PrescribedSet(id: UUID(), setIndex: $0, weightKg: weight, reps: 5, rpe: 8)
      }
    )
  }

  private func date(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0
  ) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
      ?? .distantPast
  }
}
