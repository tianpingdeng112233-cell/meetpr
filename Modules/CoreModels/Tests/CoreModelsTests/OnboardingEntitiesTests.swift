import CoreModels
import Foundation
import Testing

// MARK: - Vocabulary (verbatim against backend src/db/types.ts)

@Test func unitPreferenceVocabularyMatchesBackendVerbatim() {
  #expect(UnitPreference.allCases.map(\.rawValue) == ["kg", "lb"])
}

@Test func genderVocabularyMatchesBackendVerbatim() {
  #expect(Gender.allCases.map(\.rawValue) == ["male", "female", "other"])
}

@Test func squatStanceVocabularyMatchesBackendVerbatim() {
  #expect(SquatStance.allCases.map(\.rawValue) == ["high_bar", "low_bar"])
}

@Test func deadliftStyleVocabularyMatchesBackendVerbatim() {
  #expect(DeadliftStance.allCases.map(\.rawValue) == ["conventional", "sumo", "both"])
}

@Test func benchGripVocabularyMatchesBackendVerbatim() {
  #expect(BenchGrip.allCases.map(\.rawValue) == ["narrow", "standard", "wide"])
}

@Test func gymTierVocabularyMatchesBackendVerbatim() {
  #expect(GymTier.allCases.map(\.rawValue) == ["home_with_rack", "commercial", "professional"])
}

@Test func trainingDayVocabularyMatchesBackendVerbatim() {
  #expect(
    TrainingDay.allCases.map(\.rawValue) == ["mon", "tue", "wed", "thu", "fri", "sat", "sun"])
}

@Test func injuryAreaVocabularyMatchesBackendVerbatim() {
  #expect(
    InjuryArea.allCases.map(\.rawValue) == [
      "shoulder", "elbow", "wrist", "lower_back", "hip", "knee", "ankle", "other",
    ])
}

@Test func strengthenMuscleGroupsAreTenUniqueBackendTokens() {
  let tokens = OnboardingProfile.strengthenMuscleGroups.map(\.rawValue)
  #expect(
    tokens == [
      "quad", "hamstring", "glute", "back", "chest", "shoulder", "triceps", "biceps", "core",
      "calf",
    ])
  #expect(Set(tokens).count == tokens.count)
}

// MARK: - OnboardingProfile Codable round trip

@Test func onboardingProfileRoundTripPreservesAllFields() throws {
  let profile = OnboardingProfile(
    userId: try fixtureUUID("60000000-0000-0000-0000-000000000001"),
    unitPreference: .kg,
    gender: .male,
    birthDate: "2001-03-15",
    heightCm: try fixtureDecimal("178.0"),
    weightKg: try fixtureDecimal("83.25"),
    trainingYears: 3,
    squatStance: .lowBar,
    deadliftStyle: .conventional,
    benchGrip: nil,
    squat1RMKg: try fixtureDecimal("180.00"),
    bench1RMKg: try fixtureDecimal("120.00"),
    deadlift1RMKg: try fixtureDecimal("220.00"),
    trainingDays: [.mon, .wed, .fri, .sat],
    gymTier: .commercial,
    equipmentOverrides: ["barbell_dumbbell", "squat_bench_rack"],
    dailyLifeIntensity: 3,
    lifeStress: 4,
    recoverySpeed: 3,
    sleepHours: 3,
    muscleGroupsToStrengthen: [.quad, .hamstring, .shoulder],
    uploadAttachmentIds: [try fixtureUUID("60000000-0000-0000-0000-00000000000a")],
    injuryNotes: "左肩撞击综合征",
    injuryAreas: [.shoulder],
    isCompeting: true,
    competitionDate: "2026-07-25",
    targetWeightClass: "IPF 83kg",
    noteToCoach: "想冲全国赛",
    completedAt: Date(timeIntervalSince1970: 1_779_000_000),
    createdAt: Date(timeIntervalSince1970: 1_778_000_000),
    updatedAt: Date(timeIntervalSince1970: 1_779_000_000)
  )

  let json = try encodedJSONString(profile)
  let decoded = try MeetPRCodec.decoder.decode(OnboardingProfile.self, from: Data(json.utf8))

  #expect(decoded == profile)
  #expect(decoded.isCompleted)
  #expect(json.contains(#""birth_date":"2001-03-15""#))
}

@Test func onboardingProfileEmptyShellRoundTrips() throws {
  let profile = OnboardingProfile(
    userId: try fixtureUUID("60000000-0000-0000-0000-000000000002"),
    createdAt: Date(timeIntervalSince1970: 1_778_000_000),
    updatedAt: Date(timeIntervalSince1970: 1_778_000_000)
  )

  let json = try encodedJSONString(profile)
  let decoded = try MeetPRCodec.decoder.decode(OnboardingProfile.self, from: Data(json.utf8))

  #expect(decoded == profile)
  #expect(!decoded.isCompleted)
  #expect(decoded.trainingDays.isEmpty)
}

// MARK: - Patch semantics

@Test func patchEqualityDistinguishesAllThreeStates() {
  #expect(Patch<Int>.absent == Patch<Int>.absent)
  #expect(Patch<Int>.null == Patch<Int>.null)
  #expect(Patch<Int>.value(3) == Patch<Int>.value(3))
  #expect(Patch<Int>.absent != Patch<Int>.null)
  #expect(Patch<Int>.null != Patch<Int>.value(3))
  #expect(Patch<Int>.value(3) != Patch<Int>.value(4))
}

@Test func emptyPatchIsAllAbsentAndTouchesNoOneRM() {
  let patch = OnboardingPatch.empty
  #expect(patch.unitPreference.isAbsent)
  #expect(patch.uploadAttachmentIds.isAbsent)
  #expect(!patch.touchesOneRM)
}

@Test func touchesOneRMFlagsEachLockedField() {
  var patch = OnboardingPatch()
  patch.squat1RMKg = .value(180)
  #expect(patch.touchesOneRM)

  patch = OnboardingPatch()
  patch.bench1RMKg = .null
  #expect(patch.touchesOneRM)

  patch = OnboardingPatch()
  patch.deadlift1RMKg = .value(220)
  #expect(patch.touchesOneRM)
}
