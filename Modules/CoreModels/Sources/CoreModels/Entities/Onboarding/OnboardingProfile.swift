import Foundation

/// Student onboarding archive (spec 032). Server snapshot of the 29 product
/// fields plus metadata — field-for-field mirror of the backend
/// student_onboarding_profiles wire shape (backend spec 005 §endpoint E,
/// migration 0013). The mutable wizard working copy is `OnboardingDraft`
/// (StudentKit); this type stays immutable.
public struct OnboardingProfile: Codable, Hashable, Sendable {
  public let userId: UUID
  // Step 1
  public let unitPreference: UnitPreference?
  public let gender: Gender?
  /// "yyyy-MM-dd" date-only string end to end (no Date: avoids UTC-midnight
  /// timezone drift, spec 030 checkinDate precedent).
  public let birthDate: String?
  public let heightCm: Decimal?
  public let weightKg: Decimal?
  // Step 2
  /// 0-10 notches; 0 = <1 year, 10 = 10+ years (spec 032 D8).
  public let trainingYears: Int?
  public let squatStance: SquatStance?
  public let deadliftStyle: DeadliftStance?
  public let benchGrip: BenchGrip?
  // Step 3
  public let squat1RMKg: Decimal?
  public let bench1RMKg: Decimal?
  public let deadlift1RMKg: Decimal?
  // Step 4
  public let trainingDays: [TrainingDay]
  public let gymTier: GymTier?
  /// Final checked set of iOS-owned equipment tokens (spec 032 D3), not a diff.
  public let equipmentOverrides: [String]
  // Step 5 — all 1-5 notches (spec 032 D8)
  public let dailyLifeIntensity: Int?
  public let lifeStress: Int?
  public let recoverySpeed: Int?
  public let sleepHours: Int?
  // Step 6
  public let muscleGroupsToStrengthen: [MuscleGroup]
  public let uploadAttachmentIds: [UUID]
  // Step 7
  public let injuryNotes: String?
  public let injuryAreas: [InjuryArea]
  public let isCompeting: Bool?
  /// "yyyy-MM-dd" date-only string.
  public let competitionDate: String?
  public let targetWeightClass: String?
  public let noteToCoach: String?
  // Metadata
  public let completedAt: Date?
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    userId: UUID,
    unitPreference: UnitPreference? = nil,
    gender: Gender? = nil,
    birthDate: String? = nil,
    heightCm: Decimal? = nil,
    weightKg: Decimal? = nil,
    trainingYears: Int? = nil,
    squatStance: SquatStance? = nil,
    deadliftStyle: DeadliftStance? = nil,
    benchGrip: BenchGrip? = nil,
    squat1RMKg: Decimal? = nil,
    bench1RMKg: Decimal? = nil,
    deadlift1RMKg: Decimal? = nil,
    trainingDays: [TrainingDay] = [],
    gymTier: GymTier? = nil,
    equipmentOverrides: [String] = [],
    dailyLifeIntensity: Int? = nil,
    lifeStress: Int? = nil,
    recoverySpeed: Int? = nil,
    sleepHours: Int? = nil,
    muscleGroupsToStrengthen: [MuscleGroup] = [],
    uploadAttachmentIds: [UUID] = [],
    injuryNotes: String? = nil,
    injuryAreas: [InjuryArea] = [],
    isCompeting: Bool? = nil,
    competitionDate: String? = nil,
    targetWeightClass: String? = nil,
    noteToCoach: String? = nil,
    completedAt: Date? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.userId = userId
    self.unitPreference = unitPreference
    self.gender = gender
    self.birthDate = birthDate
    self.heightCm = heightCm
    self.weightKg = weightKg
    self.trainingYears = trainingYears
    self.squatStance = squatStance
    self.deadliftStyle = deadliftStyle
    self.benchGrip = benchGrip
    self.squat1RMKg = squat1RMKg
    self.bench1RMKg = bench1RMKg
    self.deadlift1RMKg = deadlift1RMKg
    self.trainingDays = trainingDays
    self.gymTier = gymTier
    self.equipmentOverrides = equipmentOverrides
    self.dailyLifeIntensity = dailyLifeIntensity
    self.lifeStress = lifeStress
    self.recoverySpeed = recoverySpeed
    self.sleepHours = sleepHours
    self.muscleGroupsToStrengthen = muscleGroupsToStrengthen
    self.uploadAttachmentIds = uploadAttachmentIds
    self.injuryNotes = injuryNotes
    self.injuryAreas = injuryAreas
    self.isCompeting = isCompeting
    self.competitionDate = competitionDate
    self.targetWeightClass = targetWeightClass
    self.noteToCoach = noteToCoach
    self.completedAt = completedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension OnboardingProfile {
  public var isCompleted: Bool { completedAt != nil }

  /// Memberwise muscle-group whitelist for the Step 6 "想增强" chips
  /// (spec 032 D4: wiki's "back" and "erector" merge into one `back` token;
  /// two chips would emit a duplicate token and trip zod uniqueItems).
  public static let strengthenMuscleGroups: [MuscleGroup] = [
    .quad, .hamstring, .glute, .back, .chest, .shoulder, .triceps, .biceps, .core, .calf,
  ]

  /// Keep MeetPRCodec round-trips stable: the default key for `squat1RMKg`
  /// snake-cases to "squat1_rm_kg" but decodes back as "squat1RmKg" and the
  /// lookup misses. These string values survive the encoder/decoder pair.
  /// (Wire mapping to `squat_1rm_kg` lives in OnboardingProfileDTO.)
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
