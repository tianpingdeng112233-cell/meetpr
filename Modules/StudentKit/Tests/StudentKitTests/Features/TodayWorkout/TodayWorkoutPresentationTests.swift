import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Suite struct TodayWorkoutPresentationTests {
  @Test func zeroLogDashboardCTAFramesListHeroWithoutSkippingPreStartState() throws {
    let fixture = makeFixture()
    let listFrame = CGRect(x: 20, y: 120, width: 350, height: 420)
    let laterRecordingFrame = CGRect(x: 20, y: 120, width: 350, height: 260)

    let dashboardDestination = TodayWorkoutPresentation(
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
    let measurement = TodayWorkoutHeroFrameMeasurement(
      heroMode: dashboardDestination.heroMode,
      requestToken: 1,
      frame: listFrame
    )
    var latch = LaunchDestinationFrameLatch()
    latch.arm()
    let publishedFrame = try #require(measurement.publishableFrame)
    let capturedListFrame = latch.capture(publishedFrame)
    let overwroteListFrame = latch.capture(laterRecordingFrame)

    #expect(dashboardDestination.heroMode == .list)
    #expect(!dashboardDestination.allowsManualCompletion)
    #expect(capturedListFrame)
    #expect(!overwroteListFrame)
    #expect(latch.frame == listFrame)
    #expect(recording.heroMode == .recording)
    // Started but nothing recorded yet: hold-to-complete must stay hidden —
    // there is no skip-this-day in sequence progression (David 2026-08-07).
    #expect(!recording.allowsManualCompletion)
    #expect(recording.currentRow?.stableIndex == 0)
  }

  @Test func manualCompletionUnlocksOnlyAfterARecordedSetFailedIncluded() {
    var fixture = makeFixture()
    fixture.drafts[0].failed = true

    let presentation = TodayWorkoutPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      started: true
    )

    #expect(presentation.allowsManualCompletion)
  }

  @Test func partialRealLogDashboardCTAFramesAndLatchesRecordingHero() throws {
    var fixture = makeFixture()
    fixture.drafts[0].completed = true
    let staleListFrame = CGRect(x: 20, y: 120, width: 350, height: 420)
    let recordingFrame = CGRect(x: 20, y: 120, width: 350, height: 260)

    let presentation = TodayWorkoutPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      started: false
    )
    let measurement = TodayWorkoutHeroFrameMeasurement(
      heroMode: presentation.heroMode,
      requestToken: 1,
      frame: recordingFrame
    )
    var latch = LaunchDestinationFrameLatch()
    latch.arm()
    let publishedFrame = try #require(measurement.publishableFrame)
    let capturedRecordingFrame = latch.capture(publishedFrame)
    let overwroteRecordingFrame = latch.capture(staleListFrame)

    #expect(presentation.heroMode == .recording)
    #expect(measurement.heroMode == .recording)
    #expect(capturedRecordingFrame)
    #expect(!overwroteRecordingFrame)
    #expect(latch.frame == recordingFrame)
    #expect(presentation.allowsManualCompletion)
    #expect(presentation.progress.remainingSets == 2)
    #expect(presentation.progress.remainingExercises == 2)
    #expect(presentation.progress.currentSetNumber == 2)
    #expect(presentation.progress.currentSetTotal == 2)
    #expect(presentation.progress.currentExerciseNumber == 1)
    #expect(presentation.progress.positionText == "第 2 / 2 组 · 动作 1 / 2")
    #expect(presentation.progress.remainingText == "还有 2 个动作 · 2 组未记录")
    #expect(presentation.currentRow?.stableIndex == 1)
    #expect(presentation.currentRow?.record.index == 2)
  }

  @Test func assumedHistoryDoesNotStartColdLaunchWorkout() {
    var fixture = makeFixture()
    for index in fixture.drafts.indices {
      fixture.drafts[index].completed = true
      fixture.drafts[index].assumed = true
      fixture.drafts[index].loggedSetID = UUID()
    }

    let presentation = TodayWorkoutPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      started: false
    )

    #expect(presentation.heroMode == .list)
    #expect(!presentation.hasAnyLoggedSet)
    #expect(!presentation.allowsManualCompletion)
  }

  @Test func failedRealLogResumesColdLaunchWorkout() {
    var fixture = makeFixture()
    fixture.drafts[0].failed = true

    let presentation = TodayWorkoutPresentation(
      day: fixture.day,
      drafts: fixture.drafts,
      references: [:],
      started: false
    )

    #expect(presentation.heroMode == .recording)
    #expect(presentation.hasAnyLoggedSet)
    #expect(presentation.allowsManualCompletion)
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

  @Test func zeroSetDayHasNoRemainingWork() {
    let day = StudentPlanDay(id: UUID(), date: Date(), exercises: [])
    let progress = TodayWorkoutProgress(day: day, drafts: [])

    #expect(progress.allDone)
    #expect(progress.remainingSets == 0)
    #expect(progress.remainingExercises == 0)
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
