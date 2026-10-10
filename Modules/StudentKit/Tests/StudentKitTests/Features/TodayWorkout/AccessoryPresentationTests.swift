import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func accessoryPresentationOnlyReplacesEditableRecordingAndAdvancesAfterLastSet() async throws
{
  let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
  var drafts = try #require(fixture.model.currentDrafts)
  func presentation(started: Bool) -> TodayWorkoutPresentation {
    TodayWorkoutPresentation(day: fixture.day, drafts: drafts, references: [:], started: started)
  }
  #expect(presentation(started: false).accessoryExercise(isEditable: true) == nil)
  #expect(presentation(started: true).accessoryExercise(isEditable: false) == nil)
  #expect(
    presentation(started: true).accessoryExercise(isEditable: true)?.id
      == fixture.day.exercises[0].id)
  for index in drafts.indices { drafts[index].completed = true }
  #expect(presentation(started: true).accessoryExercise(isEditable: true) == nil)

  let mainDay = StudentDemoSeed.makePlanView().days[0]
  let mainDrafts = TodayWorkoutViewModel.makeDrafts(for: mainDay, existingLogs: [])
  #expect(
    TodayWorkoutPresentation(day: mainDay, drafts: mainDrafts, references: [:], started: true)
      .accessoryExercise(isEditable: true) == nil)
  let mixedDay = StudentPlanDay(
    id: UUID(), date: fixture.day.date,
    exercises: fixture.day.exercises + mainDay.exercises)
  let mixed = TodayWorkoutPresentation(
    day: mixedDay, drafts: drafts + mainDrafts,
    references: [:], started: true)
  #expect(mixed.currentRow?.draft.planExerciseID == mainDay.exercises[0].id)
  #expect(mixed.accessoryExercise(isEditable: true) == nil)
}
