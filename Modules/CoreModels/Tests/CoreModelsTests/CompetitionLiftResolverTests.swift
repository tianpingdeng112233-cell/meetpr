import CoreModels
import Foundation
import Testing

@Test func competitionStanceVocabularyMatchesBackendVerbatim() {
  #expect(
    CompetitionStance.allCases.map(\.rawValue)
      == ["low_bar", "high_bar", "conventional", "sumo"]
  )
}

@Test func exerciseCompetitionStanceDecodesAndLegacyPayloadDefaultsToNil() throws {
  let exercise = makeExercise(
    family: .squat,
    isCompetitionLift: false,
    competitionStance: .lowBar
  )
  let data = try MeetPRCodec.encoder.encode(exercise)
  let decoded = try MeetPRCodec.decoder.decode(Exercise.self, from: data)
  #expect(decoded.competitionStance == .lowBar)

  var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  object.removeValue(forKey: "competition_stance")
  let legacyData = try JSONSerialization.data(withJSONObject: object)
  let legacy = try MeetPRCodec.decoder.decode(Exercise.self, from: legacyData)
  #expect(legacy.competitionStance == nil)
}

@Test func competitionFamilyResolverCoversStanceDecisionMatrix() {
  let lowBar = makeExercise(
    family: .squat, isCompetitionLift: false, competitionStance: .lowBar)
  let highBar = makeExercise(
    family: .squat, isCompetitionLift: false, competitionStance: .highBar)
  let conventional = makeExercise(
    family: .deadlift, isCompetitionLift: true, competitionStance: .conventional)
  let sumo = makeExercise(
    family: .deadlift, isCompetitionLift: true, competitionStance: .sumo)

  #expect(resolveCompetitionFamily(exercise: lowBar, onboarding: profile(squat: .lowBar)) == .squat)
  #expect(resolveCompetitionFamily(exercise: lowBar, onboarding: profile(squat: .highBar)) == nil)
  #expect(
    resolveCompetitionFamily(exercise: highBar, onboarding: profile(squat: .highBar)) == .squat)
  #expect(resolveCompetitionFamily(exercise: highBar, onboarding: profile(squat: .lowBar)) == nil)
  #expect(resolveCompetitionFamily(exercise: lowBar, onboarding: profile()) == .squat)

  #expect(
    resolveCompetitionFamily(exercise: conventional, onboarding: profile(deadlift: .conventional))
      == .deadlift)
  #expect(
    resolveCompetitionFamily(exercise: conventional, onboarding: profile(deadlift: .sumo)) == nil)
  #expect(
    resolveCompetitionFamily(exercise: sumo, onboarding: profile(deadlift: .sumo)) == .deadlift)
  #expect(
    resolveCompetitionFamily(exercise: sumo, onboarding: profile(deadlift: .conventional)) == nil)
  #expect(
    resolveCompetitionFamily(exercise: conventional, onboarding: profile(deadlift: .both))
      == .deadlift)
  #expect(
    resolveCompetitionFamily(exercise: sumo, onboarding: profile(deadlift: .both)) == .deadlift)
  #expect(resolveCompetitionFamily(exercise: conventional, onboarding: profile()) == .deadlift)
  #expect(resolveCompetitionFamily(exercise: sumo, onboarding: nil) == .deadlift)
}

@Test func competitionFamilyResolverIncludesGenericCompetitionLiftAndRejectsVariation() {
  let genericBench = makeExercise(family: .bench, isCompetitionLift: true)
  let genericSquat = makeExercise(family: .squat, isCompetitionLift: true)
  let variation = makeExercise(family: .deadlift, isCompetitionLift: false)
  let accessory = makeExercise(family: nil, isCompetitionLift: false)

  #expect(resolveCompetitionFamily(exercise: genericBench, onboarding: profile()) == .bench)
  #expect(
    resolveCompetitionFamily(exercise: genericSquat, onboarding: profile(squat: .highBar))
      == .squat)
  #expect(resolveCompetitionFamily(exercise: variation, onboarding: profile()) == nil)
  #expect(resolveCompetitionFamily(exercise: accessory, onboarding: profile()) == nil)
}

private func makeExercise(
  family: LiftFamily?,
  isCompetitionLift: Bool,
  competitionStance: CompetitionStance? = nil
) -> Exercise {
  Exercise(
    id: UUID(),
    name: "测试动作",
    exerciseType: family == nil ? .accessory : .mainLiftVariation,
    mainLiftFamily: family,
    isCompetitionLift: isCompetitionLift,
    competitionStance: competitionStance,
    muscleGroups: [],
    equipment: [],
    createdAt: Date(timeIntervalSince1970: 0)
  )
}

private func profile(
  squat: SquatStance? = nil,
  deadlift: DeadliftStance? = nil
) -> OnboardingProfile {
  OnboardingProfile(
    userId: UUID(),
    squatStance: squat,
    deadliftStyle: deadlift,
    createdAt: Date(timeIntervalSince1970: 0),
    updatedAt: Date(timeIntervalSince1970: 0)
  )
}
