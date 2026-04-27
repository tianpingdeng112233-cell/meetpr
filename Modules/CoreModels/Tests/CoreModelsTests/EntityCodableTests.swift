import CoreModels
import Foundation
import Testing

@Test func userCodableRoundTripPreservesIdentityFields() throws {
  let user = try makeUser()

  let json = try encodedJSONString(user)
  let decodedUser = try MeetPRCodec.decoder.decode(User.self, from: Data(json.utf8))

  #expect(decodedUser == user)
  #expect(json.contains(#""role":"coached_student""#))
  #expect(json.contains(#""created_at":"#))
  #expect(json.contains(#""height_cm":"180.5""#))
}

@Test func coachProfileCodableRoundTripPreservesValues() throws {
  let profile = CoachProfile(
    id: try fixtureUUID("10000000-0000-0000-0000-000000000001"),
    userID: try fixtureUUID("10000000-0000-0000-0000-000000000002"),
    createdAt: createdAt()
  )

  let json = try encodedJSONString(profile)
  let decodedProfile = try MeetPRCodec.decoder.decode(CoachProfile.self, from: Data(json.utf8))

  #expect(decodedProfile == profile)
  #expect(json.contains(#""user_id":"10000000-0000-0000-0000-000000000002""#))
}

@Test func studentProfileCodableRoundTripPreservesOnboardingFields() throws {
  let profile = try makeStudentProfile()

  let json = try encodedJSONString(profile)
  let decodedProfile = try MeetPRCodec.decoder.decode(StudentProfile.self, from: Data(json.utf8))

  #expect(decodedProfile == profile)
  #expect(json.contains(#""training_days_of_week":[1,3,5,6]"#))
  #expect(json.contains(#""equipment_overrides":["safety_bar","blocks"]"#))
  #expect(json.contains(#""current_squat_1rm":"180.5""#))
}

@Test func bindRequestCodableRoundTripPreservesStatusAndDates() throws {
  let request = BindRequest(
    id: try fixtureUUID("30000000-0000-0000-0000-000000000001"),
    studentID: try fixtureUUID("30000000-0000-0000-0000-000000000002"),
    coachID: try fixtureUUID("30000000-0000-0000-0000-000000000003"),
    inviteCodeID: try fixtureUUID("30000000-0000-0000-0000-000000000004"),
    status: .accepted,
    submittedAt: createdAt(),
    respondedAt: updatedAt(),
    expiredAt: nil,
    skipEvaluation: true,
    skipReason: "Existing coach assessment",
    rejectionSilent: true
  )

  let json = try encodedJSONString(request)
  let decodedRequest = try MeetPRCodec.decoder.decode(BindRequest.self, from: Data(json.utf8))

  #expect(decodedRequest == request)
  #expect(json.contains(#""invite_code_id":"30000000-0000-0000-0000-000000000004""#))
  #expect(json.contains(#""status":"accepted""#))
}

@Test func inviteCodeCodableRoundTripPreservesTypeRawValue() throws {
  let inviteCode = InviteCode(
    id: try fixtureUUID("40000000-0000-0000-0000-000000000001"),
    coachID: try fixtureUUID("40000000-0000-0000-0000-000000000002"),
    code: "ABCD123456",
    type: .personalPermanent,
    maxUses: nil,
    usedCount: 0,
    expiresAt: nil,
    revokedAt: nil,
    label: "Default code",
    createdAt: createdAt()
  )

  let json = try encodedJSONString(inviteCode)
  let decodedInviteCode = try MeetPRCodec.decoder.decode(InviteCode.self, from: Data(json.utf8))

  #expect(decodedInviteCode == inviteCode)
  #expect(json.contains(#""type":"personal_permanent""#))
}

@Test func studentProfileDecodesNullArraysAsEmptyArrays() throws {
  let json = """
    {
      "id": "20000000-0000-0000-0000-000000000001",
      "user_id": "20000000-0000-0000-0000-000000000002",
      "training_mode": "coached",
      "training_years": 4,
      "squat_stance": "low_bar",
      "deadlift_stance": "sumo",
      "current_squat_1rm": "180.5",
      "bench_1rm": "120",
      "deadlift_1rm": "220.5",
      "training_days_of_week": null,
      "gym_tier": "commercial",
      "equipment_overrides": null,
      "daily_intensity_level": 3,
      "life_stress_level": 2,
      "recovery_speed": 4,
      "sleep_hours": 8,
      "injuries": null,
      "body_part_tags": null,
      "muscles_to_strengthen": null,
      "competition_targeting": false,
      "created_at": "2026-04-27T00:00:00Z",
      "updated_at": "2026-04-27T01:00:00Z"
    }
    """

  let profile = try MeetPRCodec.decoder.decode(StudentProfile.self, from: Data(json.utf8))

  #expect(profile.trainingDaysOfWeek.isEmpty)
  #expect(profile.equipmentOverrides.isEmpty)
  #expect(profile.injuries.isEmpty)
  #expect(profile.bodyPartTags.isEmpty)
  #expect(profile.musclesToStrengthen.isEmpty)
}

private func makeUser() throws -> User {
  User(
    id: try fixtureUUID("00000000-0000-0000-0000-000000000001"),
    phone: "13800000000",
    appleUserID: "apple-user-001",
    name: "Test User",
    avatarURL: try fixtureURL("https://static.meetpr.local/avatar.png"),
    gender: .male,
    birthDate: Date(timeIntervalSince1970: 820_454_400),
    heightCm: try fixtureDecimal("180.5"),
    weightKg: try fixtureDecimal("90.25"),
    unitSystem: .metric,
    role: .coachedStudent,
    createdAt: createdAt(),
    updatedAt: updatedAt()
  )
}

private func makeStudentProfile() throws -> StudentProfile {
  StudentProfile(
    id: try fixtureUUID("20000000-0000-0000-0000-000000000001"),
    userID: try fixtureUUID("20000000-0000-0000-0000-000000000002"),
    trainingMode: .coached,
    trainingYears: 4,
    squatStance: .lowBar,
    deadliftStance: .sumo,
    benchGrip: .standard,
    currentSquat1RM: try fixtureDecimal("180.5"),
    bench1RM: try fixtureDecimal("120"),
    deadlift1RM: try fixtureDecimal("220.5"),
    trainingDaysOfWeek: [1, 3, 5, 6],
    gymTier: .commercial,
    equipmentOverrides: ["safety_bar", "blocks"],
    dailyIntensityLevel: 3,
    lifeStressLevel: 2,
    recoverySpeed: 4,
    sleepHours: 8,
    injuries: ["left_shoulder"],
    bodyPartTags: ["shoulder"],
    musclesToStrengthen: ["quad", "triceps"],
    competitionTargeting: true,
    competitionDate: Date(timeIntervalSince1970: 1_798_675_200),
    targetWeightClass: "83kg",
    notesToCoach: "Prefer morning sessions",
    createdAt: createdAt(),
    updatedAt: updatedAt()
  )
}
