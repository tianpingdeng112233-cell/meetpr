import CoreModels
import Foundation

/// GET/PUT/POST-complete response shape for /students/:id/onboarding
/// (spec 032; field names verbatim from backend spec 005 migration 0013).
///
/// Decimal columns arrive as strings ("180.0") → custom decode through
/// `decodeDecimalIfPresent`. `birth_date` / `competition_date` stay plain
/// "yyyy-MM-dd" strings end to end (never parsed into Date — UTC-midnight
/// drift, spec 030 precedent). Nullable wire arrays decode as empty arrays.
public struct OnboardingProfileDTO: Codable, Equatable, Sendable {
  public let userId: UUID
  public let unitPreference: UnitPreference?
  public let gender: Gender?
  public let birthDate: String?
  public let heightCm: Decimal?
  public let weightKg: Decimal?
  public let trainingYears: Int?
  public let squatStance: SquatStance?
  public let deadliftStyle: DeadliftStance?
  public let benchGrip: BenchGrip?
  public let squat1RMKg: Decimal?
  public let bench1RMKg: Decimal?
  public let deadlift1RMKg: Decimal?
  public let trainingDays: [TrainingDay]
  public let gymTier: GymTier?
  public let equipmentOverrides: [String]
  public let dailyLifeIntensity: Int?
  public let lifeStress: Int?
  public let recoverySpeed: Int?
  public let sleepHours: Int?
  public let muscleGroupsToStrengthen: [MuscleGroup]
  public let uploadAttachmentIds: [UUID]
  public let injuryNotes: String?
  public let injuryAreas: [InjuryArea]
  public let isCompeting: Bool?
  public let competitionDate: String?
  public let targetWeightClass: String?
  public let noteToCoach: String?
  public let completedAt: Date?
  public let createdAt: Date
  public let updatedAt: Date

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    userId = try container.decode(UUID.self, forKey: .userId)
    unitPreference = try container.decodeIfPresent(UnitPreference.self, forKey: .unitPreference)
    gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
    birthDate = try container.decodeIfPresent(String.self, forKey: .birthDate)
    heightCm = try container.decodeDecimalIfPresent(forKey: .heightCm)
    weightKg = try container.decodeDecimalIfPresent(forKey: .weightKg)
    trainingYears = try container.decodeIfPresent(Int.self, forKey: .trainingYears)
    squatStance = try container.decodeIfPresent(SquatStance.self, forKey: .squatStance)
    deadliftStyle = try container.decodeIfPresent(DeadliftStance.self, forKey: .deadliftStyle)
    benchGrip = try container.decodeIfPresent(BenchGrip.self, forKey: .benchGrip)
    squat1RMKg = try container.decodeDecimalIfPresent(forKey: .squat1RMKg)
    bench1RMKg = try container.decodeDecimalIfPresent(forKey: .bench1RMKg)
    deadlift1RMKg = try container.decodeDecimalIfPresent(forKey: .deadlift1RMKg)
    trainingDays = try container.decodeArrayIfPresent([TrainingDay].self, forKey: .trainingDays)
    gymTier = try container.decodeIfPresent(GymTier.self, forKey: .gymTier)
    equipmentOverrides = try container.decodeArrayIfPresent(
      [String].self, forKey: .equipmentOverrides)
    dailyLifeIntensity = try container.decodeIfPresent(Int.self, forKey: .dailyLifeIntensity)
    lifeStress = try container.decodeIfPresent(Int.self, forKey: .lifeStress)
    recoverySpeed = try container.decodeIfPresent(Int.self, forKey: .recoverySpeed)
    sleepHours = try container.decodeIfPresent(Int.self, forKey: .sleepHours)
    muscleGroupsToStrengthen = try container.decodeArrayIfPresent(
      [MuscleGroup].self, forKey: .muscleGroupsToStrengthen)
    uploadAttachmentIds = try container.decodeArrayIfPresent(
      [UUID].self, forKey: .uploadAttachmentIds)
    injuryNotes = try container.decodeIfPresent(String.self, forKey: .injuryNotes)
    injuryAreas = try container.decodeArrayIfPresent([InjuryArea].self, forKey: .injuryAreas)
    isCompeting = try container.decodeIfPresent(Bool.self, forKey: .isCompeting)
    competitionDate = try container.decodeIfPresent(String.self, forKey: .competitionDate)
    targetWeightClass = try container.decodeIfPresent(String.self, forKey: .targetWeightClass)
    noteToCoach = try container.decodeIfPresent(String.self, forKey: .noteToCoach)
    completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(userId, forKey: .userId)
    try container.encodeIfPresent(unitPreference, forKey: .unitPreference)
    try container.encodeIfPresent(gender, forKey: .gender)
    try container.encodeIfPresent(birthDate, forKey: .birthDate)
    try container.encodeDecimalStringIfPresent(heightCm, forKey: .heightCm)
    try container.encodeDecimalStringIfPresent(weightKg, forKey: .weightKg)
    try container.encodeIfPresent(trainingYears, forKey: .trainingYears)
    try container.encodeIfPresent(squatStance, forKey: .squatStance)
    try container.encodeIfPresent(deadliftStyle, forKey: .deadliftStyle)
    try container.encodeIfPresent(benchGrip, forKey: .benchGrip)
    try container.encodeDecimalStringIfPresent(squat1RMKg, forKey: .squat1RMKg)
    try container.encodeDecimalStringIfPresent(bench1RMKg, forKey: .bench1RMKg)
    try container.encodeDecimalStringIfPresent(deadlift1RMKg, forKey: .deadlift1RMKg)
    try container.encode(trainingDays, forKey: .trainingDays)
    try container.encodeIfPresent(gymTier, forKey: .gymTier)
    try container.encode(equipmentOverrides, forKey: .equipmentOverrides)
    try container.encodeIfPresent(dailyLifeIntensity, forKey: .dailyLifeIntensity)
    try container.encodeIfPresent(lifeStress, forKey: .lifeStress)
    try container.encodeIfPresent(recoverySpeed, forKey: .recoverySpeed)
    try container.encodeIfPresent(sleepHours, forKey: .sleepHours)
    try container.encode(muscleGroupsToStrengthen, forKey: .muscleGroupsToStrengthen)
    try container.encode(uploadAttachmentIds, forKey: .uploadAttachmentIds)
    try container.encodeIfPresent(injuryNotes, forKey: .injuryNotes)
    try container.encode(injuryAreas, forKey: .injuryAreas)
    try container.encodeIfPresent(isCompeting, forKey: .isCompeting)
    try container.encodeIfPresent(competitionDate, forKey: .competitionDate)
    try container.encodeIfPresent(targetWeightClass, forKey: .targetWeightClass)
    try container.encodeIfPresent(noteToCoach, forKey: .noteToCoach)
    try container.encodeIfPresent(completedAt, forKey: .completedAt)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
  }

  /// Explicit post-conversion key names: MeetPRCodec's convertFromSnakeCase
  /// turns `squat_1rm_kg` into "squat1RmKg" ("1rm".capitalized → "1Rm"),
  /// which the default key for `squat1RMKg` would miss.
  enum CodingKeys: String, CodingKey {
    case userId, unitPreference, gender, birthDate, heightCm, weightKg
    case trainingYears, squatStance, deadliftStyle, benchGrip
    case squat1RMKg = "squat1RmKg"
    case bench1RMKg = "bench1RmKg"
    case deadlift1RMKg = "deadlift1RmKg"
    case trainingDays, gymTier, equipmentOverrides
    case dailyLifeIntensity, lifeStress, recoverySpeed, sleepHours
    case muscleGroupsToStrengthen, uploadAttachmentIds
    case injuryNotes, injuryAreas, isCompeting, competitionDate
    case targetWeightClass, noteToCoach
    case completedAt, createdAt, updatedAt
  }
}

extension OnboardingProfileDTO {
  public func toDomain() -> OnboardingProfile {
    OnboardingProfile(
      userId: userId,
      unitPreference: unitPreference,
      gender: gender,
      birthDate: birthDate,
      heightCm: heightCm,
      weightKg: weightKg,
      trainingYears: trainingYears,
      squatStance: squatStance,
      deadliftStyle: deadliftStyle,
      benchGrip: benchGrip,
      squat1RMKg: squat1RMKg,
      bench1RMKg: bench1RMKg,
      deadlift1RMKg: deadlift1RMKg,
      trainingDays: trainingDays,
      gymTier: gymTier,
      equipmentOverrides: equipmentOverrides,
      dailyLifeIntensity: dailyLifeIntensity,
      lifeStress: lifeStress,
      recoverySpeed: recoverySpeed,
      sleepHours: sleepHours,
      muscleGroupsToStrengthen: muscleGroupsToStrengthen,
      uploadAttachmentIds: uploadAttachmentIds,
      injuryNotes: injuryNotes,
      injuryAreas: injuryAreas,
      isCompeting: isCompeting,
      competitionDate: competitionDate,
      targetWeightClass: targetWeightClass,
      noteToCoach: noteToCoach,
      completedAt: completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
