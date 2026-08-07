import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func lowBarStudentGetsSquatTitleForLowBarVariationDay() throws {
  let date = try Date("2026-07-13T12:00:00Z", strategy: .iso8601)
  let day = titleDay(date: date, stance: .lowBar)
  let context = TodayWorkoutPlanContext(
    planKind: .regular,
    weekIndex: 2,
    startDate: date
  )
  let onboarding = OnboardingProfile(
    userId: UUID(),
    squatStance: .lowBar,
    createdAt: date,
    updatedAt: date
  )

  let title = TodayWorkoutTitleResolver.title(
    day: day,
    planContext: context,
    onboarding: onboarding
  )

  #expect(title == "W1D1 · 深蹲")
}

@Test func mismatchedSquatStanceDoesNotClaimMainLiftInTitle() throws {
  let date = try Date("2026-07-13T12:00:00Z", strategy: .iso8601)
  let day = titleDay(date: date, stance: .lowBar)
  let onboarding = OnboardingProfile(
    userId: UUID(),
    squatStance: .highBar,
    createdAt: date,
    updatedAt: date
  )

  let title = TodayWorkoutTitleResolver.title(
    day: day,
    planContext: nil,
    onboarding: onboarding
  )

  #expect(title == "W1D1")
}

private func titleDay(date: Date, stance: CompetitionStance) -> StudentPlanDay {
  let exercise = Exercise(
    id: UUID(),
    name: "低杠位深蹲",
    exerciseType: .mainLiftVariation,
    mainLiftFamily: .squat,
    isCompetitionLift: false,
    competitionStance: stance,
    muscleGroups: [.quad],
    equipment: [.barbell],
    createdAt: date
  )
  return StudentPlanDay(
    id: UUID(),
    date: date,
    exercises: [
      StudentPlanExercise(
        id: UUID(),
        exercise: exercise,
        sequenceIndex: 0,
        prescribedSets: []
      )
    ]
  )
}
