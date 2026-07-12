import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func studentHeadlineUsesPerStudentCompetitionResolver() {
  let lowBar = competitionExercise(family: .squat, stance: .lowBar)
  let highBar = competitionExercise(family: .squat, stance: .highBar)
  let rdl = competitionExercise(family: .deadlift, stance: nil)
  let day = StudentPlanDay(
    id: UUID(),
    date: Date(timeIntervalSince1970: 0),
    exercises: [lowBar, highBar, rdl].enumerated().map { index, exercise in
      StudentPlanExercise(
        id: UUID(), exercise: exercise, sequenceIndex: index, prescribedSets: [])
    }
  )
  let plan = StudentPlanView(
    cycleID: UUID(), weekIndex: 1, startDate: day.date, days: [day])
  let profile = OnboardingProfile(
    userId: UUID(), squatStance: .lowBar,
    createdAt: day.date, updatedAt: day.date)

  let buckets = MainLiftExerciseFamilyResolver.exerciseIDsByFamily(
    in: plan,
    onboarding: profile
  )

  #expect(buckets[.squat] == [lowBar.id])
  #expect(buckets[.deadlift] == nil)
}

private func competitionExercise(
  family: LiftFamily,
  stance: CompetitionStance?
) -> Exercise {
  Exercise(
    id: UUID(), name: "测试动作", exerciseType: .mainLiftVariation,
    mainLiftFamily: family, isCompetitionLift: false, competitionStance: stance,
    muscleGroups: [], equipment: [], createdAt: Date(timeIntervalSince1970: 0))
}
