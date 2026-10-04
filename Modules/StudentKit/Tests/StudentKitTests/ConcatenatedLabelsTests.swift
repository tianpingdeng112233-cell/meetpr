import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func trainingDayNamesUseWholeLocalizedPhrases() {
  for (language, single, pair, empty, triple) in [
    ("en", "Deadlift day", "Squat / Bench press day", "Training day", "SBD day"),
    ("zh-Hans", "硬拉日", "深蹲卧推日", "训练日", "SBD 日"),
  ] {
    let locale = Locale(identifier: language)
    #expect(TrainingSequenceText.dayName(labelDay([.deadlift]), locale: locale) == single)
    #expect(TrainingSequenceText.dayName(labelDay([.squat, .bench]), locale: locale) == pair)
    #expect(TrainingSequenceText.dayName(labelDay([]), locale: locale) == empty)
    #expect(
      TrainingSequenceText.dayName(labelDay([.squat, .bench, .deadlift]), locale: locale) == triple)
  }
}

private func labelDay(_ families: [LiftFamily]) -> StudentPlanDay {
  let date = Date(timeIntervalSince1970: 0)
  return StudentPlanDay(
    id: UUID(), date: date,
    exercises: families.enumerated().map { index, family in
      StudentPlanExercise(
        id: UUID(),
        exercise: Exercise(
          id: UUID(), name: family.rawValue, exerciseType: .mainLift,
          mainLiftFamily: family, isCompetitionLift: true, muscleGroups: [],
          equipment: [], movementPattern: [], createdAt: date
        ), sequenceIndex: index, prescribedSets: []
      )
    }
  )
}

@Test func dashboardLiftSubtitlesUseWholeLocalizedPhrases() {
  for (language, single, pair, triple) in [
    ("en", "Deadlift day", "Squat / Bench press day", "Squat·Bench·Deadlift"),
    ("zh-Hans", "硬拉日", "深蹲、卧推日", "蹲·推·拉"),
  ] {
    let locale = Locale(identifier: language)
    #expect(DashboardTodayPresentation.liftSubtitle([.deadlift], locale: locale) == single)
    #expect(DashboardTodayPresentation.liftSubtitle([.squat, .bench], locale: locale) == pair)
    #expect(DashboardTodayPresentation.liftSubtitle([], locale: locale) == "")
    #expect(
      DashboardTodayPresentation.liftSubtitle([.squat, .bench, .deadlift], locale: locale) == triple
    )
  }
}

@Test func recoveryChipsUseWholeLocalizedPhrases() {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  for (language, expected) in [
    ("en", ["Medium Intensity", "High Stress", "About 2 days Recovery"]),
    ("zh-Hans", ["中等强度", "较高压力", "约2天恢复"]),
  ] {
    #expect(
      MyProfileV3Presentation.recoveryChips(
        profile: profile, readiness: nil, locale: Locale(identifier: language)
      ) == expected)
  }
}
