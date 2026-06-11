import CoreModels
import Foundation

/// PUT /students/me/onboarding body (spec 032 D5). Hand-written encode: the
/// three-state Patch semantics (absent key / JSON null / value) cannot be
/// synthesized, and the backend zod schema is `.strict()` — any unknown or
/// misspelled key fails the whole PUT with 400. CodingKeys are spelled out
/// in full snake_case, verbatim from backend migration 0013 (the encoder's
/// convertToSnakeCase strategy is a no-op on already-snake_case keys).
///
/// Wire guards baked in (spec 032 risks 2/4 + zod nullability):
/// - decimals round to the column scale before encoding (height 1, weight /
///   1RM 2) — the backend regex rejects longer fractions;
/// - `.null` is only encodable for the 8 nullable columns; on required
///   columns it is a programmer error (debug assert, key skipped);
/// - `upload_attachment_ids` is full-replace and not nullable: `.null` is
///   refused the same way.
public struct OnboardingPatchDTO: Encodable, Equatable, Sendable {
  public let patch: OnboardingPatch

  public init(_ patch: OnboardingPatch) {
    self.patch = patch
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // Step 1
    try encodeRequired(patch.unitPreference, key: .unitPreference, into: &container)
    try encodeRequired(patch.gender, key: .gender, into: &container)
    try encodeRequired(patch.birthDate, key: .birthDate, into: &container)
    try encodeDecimal(patch.heightCm, scale: 1, key: .heightCm, into: &container)
    try encodeDecimal(patch.weightKg, scale: 2, key: .weightKg, into: &container)
    // Step 2
    try encodeRequired(patch.trainingYears, key: .trainingYears, into: &container)
    try encodeRequired(patch.squatStance, key: .squatStance, into: &container)
    try encodeRequired(patch.deadliftStyle, key: .deadliftStyle, into: &container)
    try encodeNullable(patch.benchGrip, key: .benchGrip, into: &container)
    // Step 3
    try encodeDecimal(patch.squat1RMKg, scale: 2, key: .squat1RMKg, into: &container)
    try encodeDecimal(patch.bench1RMKg, scale: 2, key: .bench1RMKg, into: &container)
    try encodeDecimal(patch.deadlift1RMKg, scale: 2, key: .deadlift1RMKg, into: &container)
    // Step 4
    try encodeRequired(patch.trainingDays, key: .trainingDays, into: &container)
    try encodeRequired(patch.gymTier, key: .gymTier, into: &container)
    try encodeNullable(patch.equipmentOverrides, key: .equipmentOverrides, into: &container)
    // Step 5
    try encodeRequired(patch.dailyLifeIntensity, key: .dailyLifeIntensity, into: &container)
    try encodeRequired(patch.lifeStress, key: .lifeStress, into: &container)
    try encodeRequired(patch.recoverySpeed, key: .recoverySpeed, into: &container)
    try encodeRequired(patch.sleepHours, key: .sleepHours, into: &container)
    // Step 6
    try encodeNullable(
      patch.muscleGroupsToStrengthen, key: .muscleGroupsToStrengthen, into: &container)
    try encodeRequired(patch.uploadAttachmentIds, key: .uploadAttachmentIds, into: &container)
    // Step 7
    try encodeNullable(patch.injuryNotes, key: .injuryNotes, into: &container)
    try encodeNullable(patch.injuryAreas, key: .injuryAreas, into: &container)
    try encodeRequired(patch.isCompeting, key: .isCompeting, into: &container)
    try encodeNullable(patch.competitionDate, key: .competitionDate, into: &container)
    try encodeNullable(patch.targetWeightClass, key: .targetWeightClass, into: &container)
    try encodeNullable(patch.noteToCoach, key: .noteToCoach, into: &container)
  }

  /// Full snake_case names verbatim from backend migration 0013 — do not
  /// abbreviate, do not rely on the key strategy for the 1RM digit blocks.
  enum CodingKeys: String, CodingKey {
    case unitPreference = "unit_preference"
    case gender = "gender"
    case birthDate = "birth_date"
    case heightCm = "height_cm"
    case weightKg = "weight_kg"
    case trainingYears = "training_years"
    case squatStance = "squat_stance"
    case deadliftStyle = "deadlift_style"
    case benchGrip = "bench_grip"
    case squat1RMKg = "squat_1rm_kg"
    case bench1RMKg = "bench_1rm_kg"
    case deadlift1RMKg = "deadlift_1rm_kg"
    case trainingDays = "training_days"
    case gymTier = "gym_tier"
    case equipmentOverrides = "equipment_overrides"
    case dailyLifeIntensity = "daily_life_intensity"
    case lifeStress = "life_stress"
    case recoverySpeed = "recovery_speed"
    case sleepHours = "sleep_hours"
    case muscleGroupsToStrengthen = "muscle_groups_to_strengthen"
    case uploadAttachmentIds = "upload_attachment_ids"
    case injuryNotes = "injury_notes"
    case injuryAreas = "injury_areas"
    case isCompeting = "is_competing"
    case competitionDate = "competition_date"
    case targetWeightClass = "target_weight_class"
    case noteToCoach = "note_to_coach"
  }
}

extension OnboardingPatchDTO {
  /// Nullable column: `.null` encodes JSON null (explicit clear).
  fileprivate func encodeNullable<Value: Encodable & Equatable & Sendable>(
    _ patch: Patch<Value>,
    key: CodingKeys,
    into container: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    switch patch {
    case .absent:
      break
    case .null:
      try container.encodeNil(forKey: key)
    case .value(let value):
      try container.encode(value, forKey: key)
    }
  }

  /// Non-nullable column: `.null` would 400 the whole PUT, so it is refused
  /// here (debug assert, key omitted) — builders must clear via `.absent`.
  fileprivate func encodeRequired<Value: Encodable & Equatable & Sendable>(
    _ patch: Patch<Value>,
    key: CodingKeys,
    into container: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    switch patch {
    case .absent:
      break
    case .null:
      assertionFailure("Patch .null is invalid for non-nullable column \(key.rawValue)")
    case .value(let value):
      try container.encode(value, forKey: key)
    }
  }

  /// Decimal column: round to the column scale, encode as string — the
  /// backend regex `^\d+(\.\d{1,2})?$` rejects longer fractions and
  /// scientific notation (spec 032 risk 2).
  fileprivate func encodeDecimal(
    _ patch: Patch<Decimal>,
    scale: Int,
    key: CodingKeys,
    into container: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    switch patch {
    case .absent:
      break
    case .null:
      assertionFailure("Patch .null is invalid for non-nullable column \(key.rawValue)")
    case .value(let value):
      try container.encodeDecimalString(Self.rounded(value, scale: scale), forKey: key)
    }
  }

  static func rounded(_ value: Decimal, scale: Int) -> Decimal {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, scale, .plain)
    return output
  }
}
