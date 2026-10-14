import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func completedDayOverviewSeparatesPrescriptionProgressAndActualDetails() throws {
  let day = try #require(StudentDemoSeed.makePlanView().days.first)
  let exercise = try #require(day.exercises.first)
  var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  drafts[0].completed = true
  drafts[0].actualWeight = 100
  drafts[0].actualReps = 5
  drafts[0].actualRPE = nil
  var extra = try #require(StudentAddedRows.extra(exercise: exercise, drafts: drafts))
  extra.completed = true
  extra.failed = true
  extra.actualWeight = 110
  extra.actualReps = 1
  extra.actualRPE = 10
  drafts.append(extra)
  let unsavedExtra = try #require(StudentAddedRows.extra(exercise: exercise, drafts: drafts))
  drafts.append(unsavedExtra)
  let presentation = TodayWorkoutPresentation(
    day: day, drafts: drafts, references: [:], started: true)
  let overview = CompletedDayPresentation(presentation: presentation, addedDrafts: [], unit: .kg)
  let group = try #require(overview.exercises.first)
  #expect(group.loggedCount == 1)
  #expect(group.prescribedCount == 3)
  #expect(!group.isComplete)
  #expect(group.rows.count == 4)
  #expect(group.rows[0].result == "100 kg × 5")
  #expect(group.rows[1].result == "—")
  #expect(group.rows[3].isExtra)
  #expect(group.rows[3].failed)
  #expect(group.rows[3].result == "110 kg × 1 · RPE 10")
}
