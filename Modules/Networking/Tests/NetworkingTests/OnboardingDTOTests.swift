import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import Networking

// MARK: - Profile decode (full 29-field wire fixture, backend spec 005 shapes)

private let fullProfileJSON = """
  {
    "user_id": "c1000000-0000-0000-0000-000000000001",
    "unit_preference": "kg",
    "gender": "male",
    "birth_date": "2001-03-15",
    "height_cm": "178.0",
    "weight_kg": "83.25",
    "training_years": 3,
    "squat_stance": "low_bar",
    "deadlift_style": "conventional",
    "bench_grip": null,
    "squat_1rm_kg": "180.00",
    "bench_1rm_kg": "120.00",
    "deadlift_1rm_kg": "220.00",
    "training_days": ["mon", "wed", "fri", "sat"],
    "gym_tier": "commercial",
    "equipment_overrides": ["barbell_dumbbell", "squat_bench_rack", "smith_machine"],
    "daily_life_intensity": 3,
    "life_stress": 4,
    "recovery_speed": 3,
    "sleep_hours": 3,
    "muscle_groups_to_strengthen": ["quad", "hamstring", "shoulder"],
    "injury_notes": "左肩撞击综合征",
    "injury_areas": ["shoulder"],
    "is_competing": true,
    "competition_date": "2026-07-25",
    "target_weight_class": "IPF 83kg",
    "note_to_coach": "想冲全国赛",
    "completed_at": "2026-06-11T09:30:00.000Z",
    "created_at": "2026-06-10T08:00:00.000Z",
    "updated_at": "2026-06-11T09:30:00.000Z",
    "upload_attachment_ids": ["c1000000-0000-0000-0000-00000000000a"]
  }
  """

@Test func onboardingProfileDecodesFullWireFixture() throws {
  let domain = try MeetPRCodec.decoder.decode(
    OnboardingProfileDTO.self, from: Data(fullProfileJSON.utf8)
  ).toDomain()

  #expect(domain.unitPreference == .kg)
  #expect(domain.gender == .male)
  #expect(domain.birthDate == "2001-03-15")
  #expect(domain.heightCm == Decimal(string: "178.0"))
  #expect(domain.weightKg == Decimal(string: "83.25"))
  #expect(domain.trainingYears == 3)
  #expect(domain.squatStance == .lowBar)
  #expect(domain.deadliftStyle == .conventional)
  #expect(domain.benchGrip == nil)
  #expect(domain.squat1RMKg == Decimal(string: "180.00"))
  #expect(domain.bench1RMKg == Decimal(string: "120.00"))
  #expect(domain.deadlift1RMKg == Decimal(string: "220.00"))
  #expect(domain.trainingDays == [.mon, .wed, .fri, .sat])
  #expect(domain.gymTier == .commercial)
  #expect(domain.equipmentOverrides.count == 3)
  #expect(domain.dailyLifeIntensity == 3)
  #expect(domain.sleepHours == 3)
  #expect(domain.muscleGroupsToStrengthen == [.quad, .hamstring, .shoulder])
  #expect(domain.uploadAttachmentIds.count == 1)
  #expect(domain.injuryNotes == "左肩撞击综合征")
  #expect(domain.injuryAreas == [.shoulder])
  #expect(domain.isCompeting == true)
  #expect(domain.competitionDate == "2026-07-25")
  #expect(domain.targetWeightClass == "IPF 83kg")
  #expect(domain.noteToCoach == "想冲全国赛")
  #expect(domain.isCompleted)
}

@Test func onboardingProfileDecodeEncodeDecodeIsStable() throws {
  let decoded = try MeetPRCodec.decoder.decode(
    OnboardingProfileDTO.self, from: Data(fullProfileJSON.utf8))
  let reencoded = try MeetPRCodec.encoder.encode(decoded)
  let redecoded = try MeetPRCodec.decoder.decode(OnboardingProfileDTO.self, from: reencoded)

  #expect(redecoded == decoded)
}

@Test func onboardingProfileDecodesEmptyShellWithNullArrays() throws {
  let json = """
    {
      "user_id": "c1000000-0000-0000-0000-000000000002",
      "unit_preference": null,
      "gender": null,
      "birth_date": null,
      "height_cm": null,
      "weight_kg": null,
      "training_years": null,
      "squat_stance": null,
      "deadlift_style": null,
      "bench_grip": null,
      "squat_1rm_kg": null,
      "bench_1rm_kg": null,
      "deadlift_1rm_kg": null,
      "training_days": null,
      "gym_tier": null,
      "equipment_overrides": null,
      "daily_life_intensity": null,
      "life_stress": null,
      "recovery_speed": null,
      "sleep_hours": null,
      "muscle_groups_to_strengthen": null,
      "injury_notes": null,
      "injury_areas": null,
      "is_competing": null,
      "competition_date": null,
      "target_weight_class": null,
      "note_to_coach": null,
      "completed_at": null,
      "created_at": "2026-06-10T08:00:00.000Z",
      "updated_at": "2026-06-10T08:00:00.000Z",
      "upload_attachment_ids": []
    }
    """

  let domain = try MeetPRCodec.decoder.decode(OnboardingProfileDTO.self, from: Data(json.utf8))
    .toDomain()

  #expect(!domain.isCompleted)
  #expect(domain.trainingDays.isEmpty)
  #expect(domain.equipmentOverrides.isEmpty)
  #expect(domain.muscleGroupsToStrengthen.isEmpty)
  #expect(domain.uploadAttachmentIds.isEmpty)
  #expect(domain.injuryAreas.isEmpty)
}

// MARK: - Patch three-state encoding (spec 032 D5; zod .strict() defense)

private func encodedDictionary(_ patch: OnboardingPatch) throws -> [String: Any] {
  let data = try MeetPRCodec.encoder.encode(OnboardingPatchDTO(patch))
  let object = try JSONSerialization.jsonObject(with: data)
  guard let dictionary = object as? [String: Any] else {
    throw NSError(domain: "OnboardingDTOTests", code: 1)
  }
  return dictionary
}

@Test func emptyPatchEncodesEmptyBody() throws {
  let dictionary = try encodedDictionary(.empty)
  #expect(dictionary.isEmpty)
}

@Test func absentFieldsNeverAppearInBody() throws {
  var patch = OnboardingPatch()
  patch.gender = .value(.male)
  let dictionary = try encodedDictionary(patch)

  #expect(dictionary.count == 1)
  #expect(dictionary["gender"] as? String == "male")
}

@Test func nullEncodesJSONNullForNullableColumns() throws {
  var patch = OnboardingPatch()
  patch.benchGrip = .null
  patch.trainingDays = .null
  patch.injuryNotes = .null
  patch.competitionDate = .null
  let dictionary = try encodedDictionary(patch)

  #expect(dictionary.count == 4)
  #expect(dictionary["bench_grip"] is NSNull)
  #expect(dictionary["training_days"] is NSNull)
  #expect(dictionary["injury_notes"] is NSNull)
  #expect(dictionary["competition_date"] is NSNull)
}

@Test func valueFieldsEncodeBackendKeyNamesVerbatim() throws {
  var patch = OnboardingPatch()
  patch.unitPreference = .value(.lb)
  patch.birthDate = .value("2001-03-15")
  patch.heightCm = .value(Decimal(string: "178.0") ?? 0)
  patch.weightKg = .value(Decimal(string: "83.25") ?? 0)
  patch.trainingYears = .value(3)
  patch.squatStance = .value(.highBar)
  patch.deadliftStyle = .value(.sumo)
  patch.benchGrip = .value(.standard)
  patch.squat1RMKg = .value(180)
  patch.bench1RMKg = .value(120)
  patch.deadlift1RMKg = .value(220)
  patch.trainingDays = .value([.mon, .thu])
  patch.gymTier = .value(.professional)
  patch.equipmentOverrides = .value(["lifting_platform"])
  patch.dailyLifeIntensity = .value(2)
  patch.lifeStress = .value(3)
  patch.recoverySpeed = .value(4)
  patch.sleepHours = .value(5)
  patch.muscleGroupsToStrengthen = .value([.back])
  patch.uploadAttachmentIds = .value([])
  patch.injuryNotes = .value("腰部旧伤")
  patch.injuryAreas = .value([.lowerBack])
  patch.isCompeting = .value(false)
  patch.competitionDate = .value("2026-07-25")
  patch.targetWeightClass = .value("IPF 83kg")
  patch.noteToCoach = .value("多关注深蹲")
  patch.gender = .value(.other)
  let dictionary = try encodedDictionary(patch)

  let expectedKeys: Set<String> = [
    "unit_preference", "gender", "birth_date", "height_cm", "weight_kg",
    "training_years", "squat_stance", "deadlift_style", "bench_grip",
    "squat_1rm_kg", "bench_1rm_kg", "deadlift_1rm_kg",
    "training_days", "gym_tier", "equipment_overrides",
    "daily_life_intensity", "life_stress", "recovery_speed", "sleep_hours",
    "muscle_groups_to_strengthen", "upload_attachment_ids",
    "injury_notes", "injury_areas", "is_competing", "competition_date",
    "target_weight_class", "note_to_coach",
  ]
  #expect(Set(dictionary.keys) == expectedKeys)
  #expect(dictionary["unit_preference"] as? String == "lb")
  #expect(dictionary["squat_stance"] as? String == "high_bar")
  #expect(dictionary["deadlift_style"] as? String == "sumo")
  #expect(dictionary["training_days"] as? [String] == ["mon", "thu"])
  #expect(dictionary["injury_areas"] as? [String] == ["lower_back"])
  #expect(dictionary["upload_attachment_ids"] as? [String] == [])
  #expect(dictionary["is_competing"] as? Bool == false)
}

@Test func decimalsEncodeAsStringsRoundedToColumnScale() throws {
  var patch = OnboardingPatch()
  patch.heightCm = .value(Decimal(string: "178.46") ?? 0)  // height scale 1 → 178.5
  patch.weightKg = .value(Decimal(string: "83.456") ?? 0)  // weight scale 2 → 83.46
  patch.squat1RMKg = .value(Decimal(string: "180.5") ?? 0)
  let dictionary = try encodedDictionary(patch)

  #expect(dictionary["height_cm"] as? String == "178.5")
  #expect(dictionary["weight_kg"] as? String == "83.46")
  #expect(dictionary["squat_1rm_kg"] as? String == "180.5")
}

@Test func oneRMKeysSpellOutDigitBlocks() throws {
  var patch = OnboardingPatch()
  patch.squat1RMKg = .value(180)
  patch.bench1RMKg = .value(120)
  patch.deadlift1RMKg = .value(220)
  let dictionary = try encodedDictionary(patch)

  // The exact strings zod .strict() expects — a key-strategy artifact like
  // "squat1rm_kg" would 400 the whole PUT (spec 032 risk 1).
  #expect(Set(dictionary.keys) == ["squat_1rm_kg", "bench_1rm_kg", "deadlift_1rm_kg"])
  #expect(dictionary["squat_1rm_kg"] as? String == "180")
}

// MARK: - Error envelope (spec 032 §2)

@Test func onboardingIncompleteEnvelopeCarriesMissingFields() {
  let payload = #"{"error":"ONBOARDING_INCOMPLETE","missing_fields":["gender","sleep_hours"]}"#
  let error = APIError.httpStatus(422, Data(payload.utf8))

  let mapped = OnboardingError(
    machineCode: BackendErrorEnvelope.machineCode(from: error),
    missingFields: BackendErrorEnvelope.missingFields(from: error)
  )
  #expect(mapped == .incomplete(missingFields: ["gender", "sleep_hours"]))
}

@Test func oneRMLockedAndNotFoundEnvelopesMap() {
  let locked = APIError.httpStatus(403, Data(#"{"error":"ONE_RM_LOCKED"}"#.utf8))
  let lockedCode = BackendErrorEnvelope.machineCode(from: locked)
  #expect(OnboardingError(machineCode: lockedCode) == .oneRMLocked)

  let missing = APIError.httpStatus(404, Data(#"{"error":"ONBOARDING_NOT_FOUND"}"#.utf8))
  let missingCode = BackendErrorEnvelope.machineCode(from: missing)
  #expect(OnboardingError(machineCode: missingCode) == .notFound)
}
