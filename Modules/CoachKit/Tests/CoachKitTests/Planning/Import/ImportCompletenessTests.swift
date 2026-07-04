import CoreModels
import Foundation
import Testing

@testable import CoachKit

// spec 043 §H — import's own completeness gate (not the draft rules).

private func set(reps: Int?, weight: String? = nil, rpe: String? = nil) -> ImportReviewSet {
  ImportReviewSet(
    id: UUID(),
    setNumber: 1,
    targetReps: reps,
    targetRepsMax: nil,
    weightKg: weight.flatMap { Decimal(string: $0) },
    rpe: rpe.flatMap { Decimal(string: $0) },
    setType: .working,
    coachNote: nil
  )
}

@Test func setNeedsRepsAndAValidTarget() {
  #expect(ImportCompleteness.isComplete(set(reps: 5, weight: "100")))
  #expect(ImportCompleteness.isComplete(set(reps: 5, rpe: "8")))

  #expect(!ImportCompleteness.isComplete(set(reps: 0, weight: "100")))  // reps < 1
  #expect(!ImportCompleteness.isComplete(set(reps: nil, weight: "100")))  // reps missing
  #expect(!ImportCompleteness.isComplete(set(reps: 5)))  // no target
  #expect(!ImportCompleteness.isComplete(set(reps: 5, weight: "0")))  // weight not > 0
  #expect(!ImportCompleteness.isComplete(set(reps: 5, rpe: "11")))  // rpe out of 1...10
}

@Test func exerciseMustBeBoundAndAllSetsComplete() {
  let goodSets = [set(reps: 5, weight: "100")]
  let bound = ImportReviewExercise(
    id: UUID(), rawName: "深蹲", boundExerciseID: UUID(), isMainLift: true, note: nil, sets: goodSets)
  let unbound = ImportReviewExercise(
    id: UUID(), rawName: "深蹲", boundExerciseID: nil, isMainLift: false, note: nil, sets: goodSets)
  let incompleteSet = ImportReviewExercise(
    id: UUID(), rawName: "深蹲", boundExerciseID: UUID(), isMainLift: true, note: nil,
    sets: [set(reps: 5)])

  #expect(ImportCompleteness.isComplete(bound))
  #expect(!ImportCompleteness.isComplete(unbound))
  #expect(!ImportCompleteness.isComplete(incompleteSet))
}

@Test func publishableNeedsAtLeastOneSelectedWeekAllComplete() {
  let exercise = ImportReviewExercise(
    id: UUID(), rawName: "深蹲", boundExerciseID: UUID(), isMainLift: true, note: nil,
    sets: [set(reps: 5, weight: "100")])
  let day = ImportReviewDay(id: UUID(), dayOfWeek: 0, exercises: [exercise])

  let selected = ImportReviewWeek(id: UUID(), blockIndex: 0, isSelected: true, days: [day])
  let unselected = ImportReviewWeek(id: UUID(), blockIndex: 0, isSelected: false, days: [day])

  #expect(ImportCompleteness.isPublishable([selected]))
  #expect(!ImportCompleteness.isPublishable([unselected]))  // nothing selected
  #expect(!ImportCompleteness.isPublishable([]))
}

@Test func defaultStartDateIsNextMonday() {
  // 2026-04-26 is a Sunday (UTC) → next Monday is 2026-04-27.
  let sunday = Date(timeIntervalSince1970: 1_777_161_600)
  let start = ImportReviewViewModel.defaultStartDate(now: sunday)
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  #expect(calendar.component(.weekday, from: start) == 2)  // Monday
  #expect(start > sunday)
}
