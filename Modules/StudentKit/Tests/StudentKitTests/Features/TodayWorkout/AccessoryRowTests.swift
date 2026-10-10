import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func accessoryRowsPrefillOnlyActualRPEAndSelectWritablePendingSets() throws {
  let exercise = Exercise(
    id: UUID(), name: "Row", exerciseType: .accessory, isCompetitionLift: false,
    muscleGroups: [], equipment: [], createdAt: .distantPast)
  let sets = [
    PrescribedSet(id: UUID(), setIndex: 0, weightKg: 60, reps: 12, rpe: 8),
    PrescribedSet(id: UUID(), setIndex: 1, weightKg: nil, intensity: .rpe(8), reps: 12),
    PrescribedSet(
      id: UUID(), setIndex: 2, weightKg: nil, intensity: .rir(2), reps: 8,
      coachNote: "bodyweight"),
  ]
  let planExercise = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: sets)
  let day = StudentPlanDay(id: UUID(), date: Date(), exercises: [planExercise])
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  #expect(drafts.map(\.actualRPE) == [8, 8, 8])
  let previous = StudentSetLog(
    id: UUID(), studentID: UUID(), planExerciseID: UUID(), setIndex: 1,
    loggedAt: .distantPast, weightKg: 55, reps: 10, rpe: 7, completed: true)
  let rows = drafts.map {
    AccessoryRow(draft: $0, previous: $0.prescribed.setIndex == 1 ? previous : nil, unit: .kg)
  }
  #expect(rows[0].input == AccessoryInput(weight: "60", reps: "12", rpe: ""))
  #expect(rows[0].rpePlaceholder == "8")
  #expect(rows[1].input.weight.isEmpty)
  #expect(rows[1].weightPlaceholder == "55")
  #expect(!rows[1].isWritable)
  #expect(rows[2].isBodyweight)
  #expect(rows[2].rpePlaceholder == "RIR 2")
  #expect(rows[2].weightKg == 0)
  #expect(rows[2].extraNote == nil)
  #expect(AccessoryRow.selection(rows).writable.map(\.id) == [sets[0].id, sets[2].id])
  #expect(AccessoryRow.selection(rows).skipped.map(\.id) == [sets[1].id])
  var filled = rows[1]
  filled.usePrevious()
  #expect(filled.input == AccessoryInput(weight: "55", reps: "10", rpe: ""))
  #expect(filled.isWritable)
  let logged = StudentSetLog(
    id: UUID(), studentID: UUID(), planExerciseID: planExercise.id, setIndex: 0,
    loggedAt: Date(), weightKg: 65, reps: 11, rpe: nil, completed: true)
  let savedDraft = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [logged])[0]
  #expect(savedDraft.actualRPE == nil)
  let saved = AccessoryRow(draft: savedDraft, previous: nil, unit: .lb, hasVideo: true)
  #expect(saved.input.weight == "143.3")
  #expect(saved.input.rpe.isEmpty)
  #expect(saved.hasVideo)
  #expect(saved.isCancellation)
  #expect(AccessoryRow.selection([saved]).writable.isEmpty)
}

@Test func accessoryHistoryUsesSameSetIndexFromOnePreviousSession() {
  let exerciseID = UUID()
  let previousID = UUID()
  let olderID = UUID()
  let currentID = UUID()
  let studentID = UUID()
  func log(_ planID: UUID, _ index: Int, _ date: String, _ weight: Decimal) -> StudentSetLog {
    StudentSetLog(
      id: UUID(), studentID: studentID, planExerciseID: planID,
      exerciseID: exerciseID, setIndex: index,
      loggedAt: Date(timeIntervalSince1970: weight == 99 ? 1 : 0),
      loggedDate: date, weightKg: weight, reps: 12, completed: true)
  }
  let history = [
    log(olderID, 0, "2026-01-01", 45), log(olderID, 2, "2026-01-01", 45),
    log(previousID, 0, "2026-01-08", 50), log(previousID, 1, "2026-01-08", 55),
    log(currentID, 0, "2026-01-09", 99),
  ]
  let prior = AccessoryHistory.previousSession(
    logs: history, exerciseID: exerciseID, currentPlanExerciseID: currentID,
    planExerciseToExercise: [:])
  #expect(prior[0]?.weightKg == 50)
  #expect(prior[1]?.weightKg == 55)
  #expect(prior[2] == nil)
}

@MainActor
@Test func accessoryRowValidationRejectsInvalidNumbersAndPreservesZero() async throws {
  let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
  var row = AccessoryRow(
    draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .lb)
  for weight in ["", "-1", "abc", "1foo", "NaN", "∞"] {
    row.input.weight = weight
    #expect(!row.isWritable)
  }
  row.input.weight = "0"
  #expect(row.weightKg == 0 && row.isWritable)
  row.input.weight = "55.1"
  #expect(row.weightKg == 24.99)
  for reps in ["0", "100", "1.5", ""] {
    row.input.reps = reps
    #expect(!row.isWritable)
  }
  row.input.reps = "12"
  row.input.rpe = "8,5"
  #expect(row.rpe == 8.5 && row.isWritable)
  row.input.rpe = "11"
  #expect(!row.isWritable)
}
