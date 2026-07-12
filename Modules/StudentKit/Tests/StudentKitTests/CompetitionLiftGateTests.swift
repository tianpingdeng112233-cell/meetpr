import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func studentHeadlineAndRecorderUsePerStudentCompetitionResolver() {
  let lowBar = competitionExercise(family: .squat, stance: .lowBar)
  let highBar = competitionExercise(family: .squat, stance: .highBar)
  let rdl = competitionExercise(family: .deadlift, stance: nil, isCompetitionLift: false)
  let profile = onboardingProfile(squat: .lowBar)

  let buckets = MainLiftExerciseFamilyResolver.exerciseIDsByFamily(
    catalog: [lowBar, highBar, rdl],
    onboarding: profile
  )
  let recorder = MainLiftExerciseFamilyResolver.recorderFamilies(
    catalog: [lowBar, highBar, rdl],
    onboarding: profile
  )

  #expect(buckets[.squat] == [lowBar.id])
  #expect(buckets[.deadlift] == nil)
  #expect(recorder == [lowBar.id: .squat])
}

private func competitionExercise(
  family: LiftFamily,
  stance: CompetitionStance?,
  isCompetitionLift: Bool = false
) -> Exercise {
  Exercise(
    id: UUID(),
    name: "测试动作",
    exerciseType: .mainLiftVariation,
    mainLiftFamily: family,
    isCompetitionLift: isCompetitionLift,
    competitionStance: stance,
    muscleGroups: [],
    equipment: [],
    createdAt: Date(timeIntervalSince1970: 0)
  )
}

private func onboardingProfile(squat: SquatStance? = nil) -> OnboardingProfile {
  OnboardingProfile(
    userId: UUID(),
    squatStance: squat,
    createdAt: Date(timeIntervalSince1970: 0),
    updatedAt: Date(timeIntervalSince1970: 0)
  )
}
