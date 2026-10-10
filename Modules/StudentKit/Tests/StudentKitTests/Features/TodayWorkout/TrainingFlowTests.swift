import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Suite struct TrainingFlowTests {
  @Test func partitionFollowsPlanOrderAndRealResults() {
    let fixture = makeFixture()
    let untouched = fixture.presentation()
    let empty = TrainingExerciseProgress(exercises: untouched.exercises)
    #expect(empty.completed.isEmpty)
    #expect(empty.active?.stableIndex == 0)
    #expect(empty.remaining.map(\.stableIndex) == [1, 2])
  }

  @Test func partitionHandlesPartialSkippedFailedAssumedAndCancellation() {
    var fixture = makeFixture()
    fixture.drafts[0].completed = true
    #expect(TrainingExerciseProgress(exercises: fixture.presentation().exercises).completed.isEmpty)
    fixture.drafts[5].completed = true
    var progress = TrainingExerciseProgress(exercises: fixture.presentation().exercises)
    #expect(progress.completed.map(\.stableIndex) == [2])
    #expect(progress.active?.stableIndex == 0)
    fixture.drafts[1].completed = true
    fixture.drafts[2].failed = true
    progress = TrainingExerciseProgress(exercises: fixture.presentation().exercises.reversed())
    #expect(progress.completed.map(\.stableIndex) == [0, 2])
    #expect(progress.active?.stableIndex == 1)
    fixture.drafts[2].assumed = true
    #expect(
      TrainingExerciseProgress(exercises: fixture.presentation().exercises)
        .completed.map(\.stableIndex) == [2])
    for index in fixture.drafts.indices {
      fixture.drafts[index].completed = true
      fixture.drafts[index].assumed = false
    }
    progress = TrainingExerciseProgress(exercises: fixture.presentation().exercises)
    #expect(progress.completed.map(\.stableIndex) == [0, 1, 2])
    #expect(progress.active == nil && progress.remaining.isEmpty)
    fixture.drafts[1].completed = false
    progress = TrainingExerciseProgress(exercises: fixture.presentation().exercises)
    #expect(progress.completed.map(\.stableIndex) == [1, 2])
    #expect(progress.active?.stableIndex == 0)
  }

  @Test func segmentsAdvanceAndDistinguishFailure() {
    var drafts = Array(makeFixture().drafts.prefix(3))
    #expect(TrainingSetProgress.segments(drafts) == [.current, .upcoming, .upcoming])
    drafts[0].completed = true
    #expect(TrainingSetProgress.segments(drafts) == [.complete, .current, .upcoming])
    drafts[1].failed = true
    #expect(TrainingSetProgress.segments(drafts) == [.complete, .failed, .current])
    drafts[2].completed = true
    #expect(TrainingSetProgress.segments(drafts) == [.complete, .failed, .complete])
    drafts[0].assumed = true
    #expect(TrainingSetProgress.segments(drafts) == [.current, .failed, .complete])
  }

  @Test func completionDocksOnlyWhenEveryRealResultExists() {
    var fixture = makeFixture()
    for index in fixture.drafts.indices { fixture.drafts[index].completed = true }
    let done = fixture.presentation().completionAvailability(isEditable: true)
    #expect(done.button && done.sticky && !done.pill)
    fixture.drafts[5].completed = false
    let partial = fixture.presentation().completionAvailability(isEditable: true)
    #expect(partial.button && !partial.sticky && partial.pill)
    #expect(!fixture.presentation().completionAvailability(isEditable: false).button)
  }

  @Test func pageOrdersCompletedBeforeHeroAndRestoresAfterCancellation() {
    var fixture = makeFixture()
    for index in 0..<3 { fixture.drafts[index].completed = true }
    let partial = fixture.presentation().trainingFlow(isEditable: true)
    #expect(partial?.completed.map(\.stableIndex) == [0])
    #expect(partial?.completed.first?.trainingCompletedText == "已完成 · 3 组")
    #expect(partial?.hero?.stableIndex == 1)
    #expect(partial?.belowHero.map(\.stableIndex) == [1, 2])
    for index in fixture.drafts.indices { fixture.drafts[index].completed = true }
    let done = fixture.presentation().trainingFlow(isEditable: true)
    #expect(done?.hero == nil)
    #expect(done?.completion.sticky == true)
    fixture.drafts[0].completed = false
    let undone = fixture.presentation().trainingFlow(isEditable: true)
    #expect(undone?.hero?.stableIndex == 0)
    #expect(undone?.completion.sticky == false)
    #expect(fixture.presentation().trainingFlow(isEditable: false) == nil)
    fixture.day = fixture.day.replacingCompletion(completedAt: Date(), source: "manual")
    #expect(fixture.presentation().trainingFlow(isEditable: true) == nil)
    #expect(makeFixture().presentation(started: false).trainingFlow(isEditable: true) == nil)
  }

  private func makeFixture() -> TrainingFlowFixture {
    let exercises = [3, 2, 1].enumerated().map { index, count in
      StudentPlanExercise(
        id: UUID(),
        exercise: Exercise(
          id: UUID(), name: "Exercise \(index)",
          exerciseType: index == 0 ? .mainLift : .accessory,
          isCompetitionLift: index == 0, muscleGroups: [], equipment: [], createdAt: Date()),
        sequenceIndex: index,
        prescribedSets: (0..<count).map {
          PrescribedSet(id: UUID(), setIndex: $0, weightKg: 60, reps: 5, rpe: 8)
        })
    }
    let day = StudentPlanDay(id: UUID(), date: Date(), exercises: exercises)
    return TrainingFlowFixture(
      day: day, drafts: TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []))
  }
}

private struct TrainingFlowFixture {
  var day: StudentPlanDay
  var drafts: [TodayWorkoutViewModel.SetRowDraft]

  func presentation(started: Bool = true) -> TodayWorkoutPresentation {
    TodayWorkoutPresentation(day: day, drafts: drafts, references: [:], started: started)
  }
}
