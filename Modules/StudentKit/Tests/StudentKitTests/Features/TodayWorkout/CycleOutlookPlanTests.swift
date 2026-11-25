import CoreModels
import Foundation
import Testing

@testable import StudentKit

struct CycleOutlookPlanTests {
  private func exercise() throws -> Exercise {
    try #require(
      StudentDemoSeed.makePlanView().days.flatMap(\.exercises).first {
        resolveCompetitionFamily(exercise: $0.exercise, onboarding: nil) == .squat
      }?.exercise)
  }

  private func day(
    _ exercise: Exercise, week: Int, weight: Decimal,
    reps: Int = 5, completed: Bool = false
  ) -> StudentPlanDay {
    day(
      exercise, week: week,
      set: .init(id: UUID(), setIndex: 0, weightKg: weight, reps: reps), completed: completed)
  }

  private func day(
    _ exercise: Exercise, week: Int, set: PrescribedSet, completed: Bool = false
  ) -> StudentPlanDay {
    .init(
      id: UUID(), weekNumber: week, date: Date(), completedAt: completed ? Date() : nil,
      exercises: [
        .init(
          id: UUID(), exercise: exercise, sequenceIndex: 0,
          prescribedSets: [set])
      ])
  }

  private func plan(_ days: [StudentPlanDay], weeks: Int = 12) -> StudentPlanView {
    let id = UUID()
    return .init(
      cycleID: id,
      handoff: .init(
        currentPlanID: id,
        plans: [
          .init(
            id: id, name: "Fixture", weeks: weeks, completedTrainingDays: 0,
            totalTrainingDays: days.count, status: .current)
        ]), weekIndex: 1,
      startDate: Date(), publishedAt: Date(), days: days)
  }

  @Test func highestScoringDayWinsAndUnscheduledWeeksRemainUntappable() throws {
    let lift = try exercise()
    let first = day(lift, week: 1, weight: 100)
    let best = day(lift, week: 1, weight: 150)
    let plan = plan([first, best])
    let result = CycleOutlook.make(
      plan: plan, profile: nil, e1RM: [:], logs: [],
      isPreview: false, currentWeek: 5)
    let row = try #require(result.rows.first)
    #expect(result.totalWeeks == 12)
    #expect(result.scheduledWeeks == 1)
    #expect(result.initialWeekIndex == 3)
    #expect(row.cells[0].dayID == best.id)
    #expect(row.cells[0].main == "150")
    #expect(row.cells.dropFirst().allSatisfy { $0.state == .unscheduled && $0.dayID == nil })
    let page = TrainingSequenceLayout.page(days: plan.days, selectedDayID: row.cells[0].dayID)
    #expect(page.visibleWeek?.weekNumber == 1)
  }

  @Test func completedWeekSelectsActualBestAndKeepsShortfallPrescription() throws {
    let lift = try exercise()
    let first = day(lift, week: 1, weight: 100, reps: 3, completed: true)
    let second = day(lift, week: 1, weight: 150, completed: true)
    let exercise = try #require(first.exercises.first)
    let log = StudentSetLog(
      id: UUID(), studentID: UUID(), planExerciseID: exercise.id,
      setIndex: 0, loggedAt: Date(), weightKg: 180, reps: 2, rpe: 8, completed: true)
    let result = CycleOutlook.make(
      plan: plan([first, second]), profile: nil, e1RM: [:], logs: [log],
      isPreview: false, currentWeek: nil, locale: Locale(identifier: "en"))
    let cell = try #require(result.rows.first?.cells.first)
    #expect(cell.dayID == first.id)
    #expect(cell.main == "180")
    #expect(cell.sub == "×2/3 @8")
    #expect(cell.done && cell.short)
  }

  @Test func previewIgnoresActualsAndCompletion() throws {
    let lift = try exercise()
    let completed = day(lift, week: 1, weight: 150, completed: true)
    let result = CycleOutlook.make(
      plan: plan([completed]), profile: nil, e1RM: [:], logs: [],
      isPreview: true, currentWeek: 1)
    let cell = try #require(result.rows.first?.cells.first)
    #expect(!cell.done && !cell.skipped && !cell.isCurrent)
    #expect(cell.dayID == completed.id)
    #expect(result.currentWeek == nil)
  }

  @Test func rpeDefaultWithoutPlanIsSquat() {
    #expect(RPETable.defaultFamily(plan: nil, profile: nil) == .squat)
  }
}

extension CycleOutlookPlanTests {
  @Test func repRangeUsesLowerBoundForShortfall() throws {
    let lift = try exercise()
    let range = PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 4, repsMax: 6)
    let upcoming = day(lift, week: 1, set: range)
    let inRange = day(lift, week: 2, set: range, completed: true)
    let belowRange = day(lift, week: 3, set: range, completed: true)
    let studentID = UUID()
    let logs = try [(inRange, 5), (belowRange, 3)].map { day, reps in
      StudentSetLog(
        id: UUID(), studentID: studentID, planExerciseID: try #require(day.exercises.first).id,
        setIndex: 0, loggedAt: Date(), weightKg: 100, reps: reps, completed: true)
    }
    let result = CycleOutlook.make(
      plan: plan([upcoming, inRange, belowRange], weeks: 3), profile: nil, e1RM: [:], logs: logs,
      isPreview: false, currentWeek: nil)
    let cells = try #require(result.rows.first?.cells)
    #expect(cells.map(\.sub) == ["×6", "×5", "×3/4"])
    #expect(cells.map(\.short) == [false, false, true])
    #expect(cells[0].isTop)
  }

  @Test func rirUsesEquivalentRPEForLoadAndScore() throws {
    let lift = try exercise()
    let rir = day(lift, week: 1, set: .init(id: UUID(), setIndex: 0, intensity: .rir(2), reps: 3))
    let rpe = day(lift, week: 2, set: .init(id: UUID(), setIndex: 0, intensity: .rpe(8), reps: 3))
    let result = CycleOutlook.make(
      plan: plan([rir, rpe], weeks: 2), profile: nil, e1RM: [lift.id: 250], logs: [],
      isPreview: false, currentWeek: nil, locale: Locale(identifier: "zh-Hans"))
    let cells = try #require(result.rows.first?.cells)
    #expect(cells[0].main == "约215")
    #expect(cells[0].sub == "×3 @8")
    #expect(cells[0].score == cells[1].score)
  }

  @Test func weekUsesPrescriptionUntilAllLiftDaysAreComplete() throws {
    let lift = try exercise()
    let heavy = day(lift, week: 1, weight: 150, completed: true)
    let light = day(lift, week: 1, weight: 100)
    let log = StudentSetLog(
      id: UUID(), studentID: UUID(), planExerciseID: try #require(heavy.exercises.first).id,
      setIndex: 0, loggedAt: Date(), weightKg: 160, reps: 4, completed: true)
    let result = CycleOutlook.make(
      plan: plan([heavy, light], weeks: 1), profile: nil, e1RM: [:], logs: [log],
      isPreview: false, currentWeek: 1)
    let cell = try #require(result.rows.first?.cells.first)
    #expect(!cell.done)
    #expect(cell.main == "150")
    #expect(cell.sub == "×5")
    #expect(cell.dayID == heavy.id)
  }

  @Test func percentageAnchorsAndRangeUpperBoundsUseTrainingPolicy() throws {
    let lift = try exercise()
    let profile = OnboardingProfile(
      userId: UUID(), squat1RMKg: 200,
      createdAt: Date(), updatedAt: Date())
    let sets: [PrescribedSet] = [
      .init(id: UUID(), setIndex: 0, intensity: .percentage(80), reps: 3),
      .init(id: UUID(), setIndex: 0, intensity: .percentage(80), percentageAnchor: .e1RM, reps: 3),
      .init(
        id: UUID(), setIndex: 0, intensity: .percentage(80), percentageAnchor: .topSet, reps: 3),
      .init(id: UUID(), setIndex: 0, intensity: .weightRange(100, 150), reps: 2, repsMax: 5),
      .init(id: UUID(), setIndex: 0, intensity: .rpeRange(7, 8), reps: 3),
    ]
    let days = sets.enumerated().map { index, set in
      StudentPlanDay(
        id: UUID(), weekNumber: index + 1, date: Date(),
        exercises: [
          .init(id: UUID(), exercise: lift, sequenceIndex: 0, prescribedSets: [set])
        ])
    }
    let result = CycleOutlook.make(
      plan: plan(days, weeks: 5), profile: profile,
      e1RM: [lift.id: 250], logs: [], isPreview: false, currentWeek: 1,
      locale: Locale(identifier: "zh-Hans"))
    let cells = try #require(result.rows.first?.cells)
    #expect(cells.map(\.main) == ["160", "200", "80%", "150", "约215"])
    #expect(cells[3].sub == "×5")
    #expect(cells[2].ratio == 0.6)
    #expect(!cells[2].isTop)
  }

  @Test func localizedLabelsAndPoundsNeverAlterComparisons() throws {
    let weeks = [
      CycleOutlookWeek(
        state: .scheduled,
        plan: .init(weightKg: 100, reps: 5)),
      .init(
        state: .scheduled,
        plan: .init(weightKg: 110, reps: 3)), .init(state: .unscheduled), .init(state: .notTrained),
    ]
    let kgCells = CycleOutlook.row(weeks: weeks, locale: Locale(identifier: "zh-Hans"))
    let lbCells = CycleOutlook.row(weeks: weeks, unit: .lb, locale: Locale(identifier: "en"))
    #expect(kgCells.map(\.ratio) == lbCells.map(\.ratio))
    #expect(kgCells.map(\.isTop) == lbCells.map(\.isTop))
    #expect(lbCells[0].main == "220.5")
    #expect(lbCells[2].main == "Unplanned")
    #expect(lbCells[3].main == "No lift")
    #expect(StudentStrings.localized(.cycleTitle, locale: Locale(identifier: "zh-Hant")) == "整個週期")
  }
}
