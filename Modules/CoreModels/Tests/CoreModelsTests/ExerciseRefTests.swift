import Foundation
import Testing

@testable import CoreModels

@Test func exerciseNotePreservesReferenceAndCanonicalBody() throws {
  let reference = ExerciseRefV1(
    exerciseName: "深蹲", dayDate: "2026-11-10", planDayID: UUID(),
    planExerciseID: UUID(), exerciseID: UUID())
  #expect(reference.body(note: "最后一组很难", english: false) == "[动作留言] 深蹲 · 11/10\n最后一组很难")
  #expect(reference.body(note: "Hard set", english: true) == "[Exercise note] 深蹲 · 11/10\nHard set")
  let data = try JSONEncoder().encode(reference)
  #expect(try JSONDecoder().decode(ExerciseRefV1.self, from: data) == reference)
}

@Test func exerciseNoteDateFallbackNeverSilentlySelectsAnotherDay() {
  let date = Date(timeIntervalSince1970: 1_794_268_800)
  let day = StudentPlanDay(id: UUID(), date: date, exercises: [])
  let dateString = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
  let dated = ExerciseRefV1(
    exerciseName: "Bench", dayDate: dateString, planDayID: nil,
    planExerciseID: nil, exerciseID: UUID())
  #expect(ExerciseNoteDayResolver.resolve(dated, days: [day])?.id == day.id)
  let missing = ExerciseRefV1(
    exerciseName: "Bench", dayDate: dateString, planDayID: UUID(),
    planExerciseID: nil, exerciseID: UUID())
  #expect(ExerciseNoteDayResolver.resolve(missing, days: [day]) == nil)
}
