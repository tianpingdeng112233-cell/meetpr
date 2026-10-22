import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func traditionalStudentNamesPreserveUserAuthoredExercises() {
  let locale = Locale(identifier: "zh-Hant-TW")
  func exercise(coachID: UUID?) -> Exercise {
    Exercise(
      id: UUID(), name: "杠铃卧推", nameEn: "Barbell Bench Press", exerciseType: .accessory,
      isCompetitionLift: false, muscleGroups: [], equipment: [], createdByCoachID: coachID,
      createdAt: Date(timeIntervalSince1970: 0))
  }
  let catalog = exercise(coachID: nil)
  #expect(StudentExerciseName.display(catalog, locale: locale) == "槓鈴臥推")
  #expect(StudentExerciseName.display(exercise(coachID: UUID()), locale: locale) == "杠铃卧推")
  #expect(StudentExerciseName.display(catalog, locale: Locale(identifier: "zh-Hans")) == "杠铃卧推")
  #expect(
    StudentExerciseName.display(catalog, locale: Locale(identifier: "en")) == "Barbell Bench Press")
  #expect(StudentExerciseTag.all.matches(catalog, search: "臥推"))
}

@Test func traditionalStudentWeekdayAndReminderUseWeekCharacter() throws {
  let locale = Locale(identifier: "zh-Hant-TW")
  let date = try #require(
    Calendar(identifier: .gregorian).date(
      from: DateComponents(year: 2030, month: 8, day: 18, hour: 12)))
  #expect(StudentFormatting.weekday(date, locale: locale) == "週日")
  let settings = TrainingReminderSettings(
    isEnabled: true, weekdays: [.monday, .wednesday], hour: 20, minute: 0)
  #expect(TrainingReminderCopy.summary(for: settings, locale: locale) == "週一·三 20:00")
}

@MainActor
@Test func traditionalTrainingDraftPreservesSameNamedCustomExercise() {
  let exercise = Exercise(
    id: UUID(), name: "杠铃卧推", exerciseType: .accessory, isCompetitionLift: false,
    muscleGroups: [], equipment: [], createdByCoachID: UUID(),
    createdAt: Date(timeIntervalSince1970: 0))
  let set = PrescribedSet(id: UUID(), setIndex: 0)
  let slot = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: [set])
  let draft = TodayWorkoutViewModel.makeDraft(exercise: slot, set: set, existingLogs: [])
  #expect(draft.displayExerciseName(locale: Locale(identifier: "zh-Hant")) == "杠铃卧推")
}
