import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Suite struct TodayWorkoutPresentationTests {
  @Test func untouchedWorkoutStartsInListAndStartedWorkoutUsesRecordingHero() {
    let fixture = makeFixture()

    let list = TodayWorkoutPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      started: false
    )
    let recording = TodayWorkoutPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      started: true
    )

    #expect(list.heroMode == .list)
    #expect(recording.heroMode == .recording)
    #expect(recording.currentRow?.stableIndex == 0)
  }

  @Test func existingLogForcesRecordingHeroAndProgressSharesItsPositionSource() {
    var fixture = makeFixture()
    fixture.drafts[0].completed = true

    let presentation = TodayWorkoutPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      started: false
    )

    #expect(presentation.heroMode == .recording)
    #expect(presentation.progress.remainingSets == 2)
    #expect(presentation.progress.remainingExercises == 2)
    #expect(presentation.progress.currentSetNumber == 2)
    #expect(presentation.progress.currentSetTotal == 2)
    #expect(presentation.progress.currentExerciseNumber == 1)
    #expect(presentation.progress.positionText == "第 2 / 2 组 · 动作 1 / 2")
    #expect(presentation.progress.remainingText == "还有 2 个动作 · 2 组未记录")
  }

  @Test func draftMappingKeepsFailureAndVideoSemantics() throws {
    var fixture = makeFixture()
    let setLogID = UUID()
    fixture.drafts[0].completed = true
    fixture.drafts[0].failed = true
    fixture.drafts[0].loggedSetID = setLogID

    let presentation = TodayWorkoutPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      videoStates: [setLogID: .failed],
      started: false
    )
    let row = try #require(presentation.exercises.first?.rows.first)

    #expect(row.record.status == .failed)
    #expect(row.record.videoState == .failed)
    #expect(row.record.weight == 175)
    #expect(row.record.reps == 3)
    #expect(row.record.rpe == 8.5)
  }

  @Test func rpePrescriptionWithoutWeightKeepsOptionalTarget() throws {
    let exercise = planExercise(
      name: "窄握卧推",
      sequenceIndex: 0,
      sets: [
        PrescribedSet(id: UUID(), setIndex: 0, weightKg: nil, reps: 6, rpe: 8)
      ]
    )
    let day = StudentPlanDay(id: UUID(), date: Date(), exercises: [exercise])

    let presentation = TodayWorkoutPresentation(
      day: day,
      drafts: TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []),
      references: [:],
      started: false
    )
    let row = try #require(presentation.exercises.first?.rows.first)

    #expect(row.record.weight == nil)
    #expect(row.record.reps == 6)
    #expect(row.record.rpe == 8)
  }

  @Test func emptyPlanUsesRestContentInsteadOfListHero() {
    let day = StudentPlanDay(id: UUID(), date: Date(), exercises: [])

    #expect(TodayWorkoutContentPolicy.isRestDay(day))
  }

  @Test func allDoneHasNoRemainingWork() {
    var fixture = makeFixture()
    for index in fixture.drafts.indices {
      fixture.drafts[index].completed = true
    }

    let progress = TodayWorkoutProgress(day: fixture.day, drafts: fixture.drafts)

    #expect(progress.allDone)
    #expect(progress.remainingSets == 0)
    #expect(progress.remainingExercises == 0)
  }

  private func makeFixture() -> (
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft]
  ) {
    let squat = planExercise(
      name: "深蹲",
      sequenceIndex: 0,
      sets: [
        PrescribedSet(id: UUID(), setIndex: 0, weightKg: 175, reps: 3, rpe: 8.5),
        PrescribedSet(id: UUID(), setIndex: 1, weightKg: 175, reps: 3, rpe: 8.5),
      ]
    )
    let bench = planExercise(
      name: "卧推",
      sequenceIndex: 1,
      sets: [
        PrescribedSet(id: UUID(), setIndex: 0, weightKg: 110, reps: 3, rpe: 8)
      ]
    )
    let day = StudentPlanDay(id: UUID(), date: Date(), exercises: [squat, bench])
    return (
      day,
      TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
    )
  }

  private func planExercise(
    name: String,
    sequenceIndex: Int,
    sets: [PrescribedSet]
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
      prescribedSets: sets
    )
  }
}

@Suite struct TrainingCalendarV3StateTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
  }

  @Test func pastPlannedIncompleteDayIsMissed() {
    let today = date(day: 24)
    let past = date(day: 23)
    let exercise = StudentPlanExercise(
      id: UUID(),
      exercise: Exercise(
        id: UUID(),
        name: "深蹲",
        exerciseType: .mainLift,
        isCompetitionLift: true,
        muscleGroups: [],
        equipment: [],
        createdAt: past
      ),
      sequenceIndex: 0,
      prescribedSets: [
        PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5, rpe: 8)
      ]
    )
    let day = StudentPlanDay(id: UUID(), date: past, exercises: [exercise])

    let state = TrainingCalendarV3State.resolve(
      progress: TrainingDayProgress(day: day, logs: []),
      date: past,
      today: today,
      calendar: calendar
    )

    #expect(state == .missed)
  }

  @Test func emptyPlanObjectIsRestAndNeverMissed() {
    let past = date(day: 23)
    let day = StudentPlanDay(id: UUID(), date: past, exercises: [])

    let state = TrainingCalendarV3State.resolve(
      progress: TrainingDayProgress(day: day, logs: []),
      date: past,
      today: date(day: 24),
      calendar: calendar
    )

    #expect(state == .rest)
  }

  @Test func pastRestDayIsNeverMissed() {
    let state = TrainingCalendarV3State.resolve(
      progress: TrainingDayProgress(day: nil, logs: []),
      date: date(day: 23),
      today: date(day: 24),
      calendar: calendar
    )

    #expect(state == .rest)
  }

  @Test func plannedTodayAndFutureUseTodayAndFutureStates() {
    let today = date(day: 24)
    let todayPlan = plannedDay(on: today)
    let future = date(day: 25)
    let futurePlan = plannedDay(on: future)

    #expect(
      TrainingCalendarV3State.resolve(
        progress: TrainingDayProgress(day: todayPlan, logs: []),
        date: today,
        today: today,
        calendar: calendar
      ) == .today
    )
    #expect(
      TrainingCalendarV3State.resolve(
        progress: TrainingDayProgress(day: futurePlan, logs: []),
        date: future,
        today: today,
        calendar: calendar
      ) == .future
    )
  }

  @Test func earlyMorningGymDayStillMarksPreviousCalendarDateAsToday() {
    let earlyMorning =
      calendar.date(
        from: DateComponents(year: 2026, month: 7, day: 24, hour: 3, minute: 30)
      ) ?? Date()
    let gymDay = WorkoutDatePolicy.gymDayToday(now: earlyMorning)
    let plan = StudentPlanDay(
      id: UUID(),
      date: gymDay,
      exercises: [
        StudentPlanExercise(
          id: UUID(),
          exercise: Exercise(
            id: UUID(),
            name: "深蹲",
            exerciseType: .mainLift,
            isCompetitionLift: true,
            muscleGroups: [],
            equipment: [],
            createdAt: gymDay
          ),
          sequenceIndex: 0,
          prescribedSets: [
            PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5, rpe: 8)
          ]
        )
      ]
    )

    let state = TrainingCalendarV3State.resolve(
      progress: TrainingDayProgress(day: plan, logs: []),
      date: gymDay,
      today: gymDay,
      calendar: calendar
    )

    #expect(calendar.component(.day, from: gymDay) == 23)
    #expect(state == .today)
  }

  @Test func earlyMorningEmptyGymDayIsTodayButRemainsRest() throws {
    let earlyMorning = try #require(
      calendar.date(
        from: DateComponents(year: 2026, month: 7, day: 24, hour: 3, minute: 30)
      )
    )
    let gymDay = WorkoutDatePolicy.gymDayToday(now: earlyMorning)
    let emptyPlan = StudentPlanDay(id: UUID(), date: gymDay, exercises: [])
    let days = TrainingCalendarLayout.makeDays(
      period: TrainingCalendarPeriod(
        displayedDate: gymDay,
        selectedDate: gymDay,
        today: gymDay,
        mode: .week
      ),
      cycleDays: [emptyPlan],
      logs: [],
      calendar: calendar
    )
    let selectedDay = days.first { $0.isSelected }
    let selected = try #require(selectedDay)

    #expect(selected.isToday)
    #expect(selected.progress.state == .noPlan)
    #expect(
      TrainingCalendarV3State.resolve(
        progress: selected.progress,
        date: selected.date,
        today: gymDay,
        calendar: calendar
      ) == .rest
    )
  }

  @Test func trainingCalendarTextMatchesMockupCopyExactly() {
    let friday = date(day: 24)

    #expect(TrainingCalendarText.weekday(for: friday, calendar: calendar) == "周五")
    #expect(
      TrainingCalendarText.collapsedDate(for: friday, calendar: calendar)
        == "七月24日 · 星期五"
    )
  }

  private func date(day: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 7, day: day)) ?? Date()
  }

  private func plannedDay(on date: Date) -> StudentPlanDay {
    StudentPlanDay(
      id: UUID(),
      date: date,
      exercises: [
        StudentPlanExercise(
          id: UUID(),
          exercise: Exercise(
            id: UUID(),
            name: "深蹲",
            exerciseType: .mainLift,
            isCompetitionLift: true,
            muscleGroups: [],
            equipment: [],
            createdAt: date
          ),
          sequenceIndex: 0,
          prescribedSets: [
            PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5, rpe: 8)
          ]
        )
      ]
    )
  }
}

@Suite struct TrainingCalendarScrollStateTests {
  @Test func openCalendarClosesOnlyPast56WithMoreThan200Slack() {
    let open = TrainingCalendarScrollState(isOpen: true)

    #expect(open.updating(offset: 56, contentSlack: 201).isOpen)
    #expect(open.updating(offset: 57, contentSlack: 200).isOpen)
    #expect(!open.updating(offset: 57, contentSlack: 201).isOpen)
  }

  @Test func closedCalendarReopensOnlyBelow6() {
    let closed = TrainingCalendarScrollState(isOpen: false)

    #expect(!closed.updating(offset: 6, contentSlack: 500).isOpen)
    #expect(closed.updating(offset: 5, contentSlack: 500).isOpen)
  }
}
