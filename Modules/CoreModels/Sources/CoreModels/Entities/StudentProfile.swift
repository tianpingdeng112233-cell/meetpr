import Foundation

public struct StudentProfile: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let userID: UUID
  public let trainingMode: TrainingMode
  public let trainingYears: Int
  public let squatStance: SquatStance
  public let deadliftStance: DeadliftStance
  public let benchGrip: BenchGrip?
  public let currentSquat1RM: Decimal
  public let bench1RM: Decimal
  public let deadlift1RM: Decimal
  public let trainingDaysOfWeek: [Int]
  public let gymTier: GymTier
  public let equipmentOverrides: [String]
  public let dailyIntensityLevel: Int
  public let lifeStressLevel: Int
  public let recoverySpeed: Int
  public let sleepHours: Int
  public let injuries: [String]
  public let bodyPartTags: [String]
  public let musclesToStrengthen: [String]
  public let competitionTargeting: Bool
  public let competitionDate: Date?
  public let targetWeightClass: String?
  public let notesToCoach: String?
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    userID: UUID,
    trainingMode: TrainingMode,
    trainingYears: Int,
    squatStance: SquatStance,
    deadliftStance: DeadliftStance,
    benchGrip: BenchGrip? = nil,
    currentSquat1RM: Decimal,
    bench1RM: Decimal,
    deadlift1RM: Decimal,
    trainingDaysOfWeek: [Int],
    gymTier: GymTier,
    equipmentOverrides: [String] = [],
    dailyIntensityLevel: Int,
    lifeStressLevel: Int,
    recoverySpeed: Int,
    sleepHours: Int,
    injuries: [String] = [],
    bodyPartTags: [String] = [],
    musclesToStrengthen: [String] = [],
    competitionTargeting: Bool,
    competitionDate: Date? = nil,
    targetWeightClass: String? = nil,
    notesToCoach: String? = nil,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.userID = userID
    self.trainingMode = trainingMode
    self.trainingYears = trainingYears
    self.squatStance = squatStance
    self.deadliftStance = deadliftStance
    self.benchGrip = benchGrip
    self.currentSquat1RM = currentSquat1RM
    self.bench1RM = bench1RM
    self.deadlift1RM = deadlift1RM
    self.trainingDaysOfWeek = trainingDaysOfWeek
    self.gymTier = gymTier
    self.equipmentOverrides = equipmentOverrides
    self.dailyIntensityLevel = dailyIntensityLevel
    self.lifeStressLevel = lifeStressLevel
    self.recoverySpeed = recoverySpeed
    self.sleepHours = sleepHours
    self.injuries = injuries
    self.bodyPartTags = bodyPartTags
    self.musclesToStrengthen = musclesToStrengthen
    self.competitionTargeting = competitionTargeting
    self.competitionDate = competitionDate
    self.targetWeightClass = targetWeightClass
    self.notesToCoach = notesToCoach
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DecodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    userID = try container.decode(UUID.self, forKey: .userID)
    trainingMode = try container.decode(TrainingMode.self, forKey: .trainingMode)
    trainingYears = try container.decode(Int.self, forKey: .trainingYears)
    squatStance = try container.decode(SquatStance.self, forKey: .squatStance)
    deadliftStance = try container.decode(DeadliftStance.self, forKey: .deadliftStance)
    benchGrip = try container.decodeIfPresent(BenchGrip.self, forKey: .benchGrip)
    currentSquat1RM = try container.decodeDecimal(forKey: .currentSquat1RM)
    bench1RM = try container.decodeDecimal(forKey: .bench1RM)
    deadlift1RM = try container.decodeDecimal(forKey: .deadlift1RM)
    trainingDaysOfWeek = try container.decodeArrayIfPresent(
      [Int].self,
      forKey: .trainingDaysOfWeek
    )
    gymTier = try container.decode(GymTier.self, forKey: .gymTier)
    equipmentOverrides = try container.decodeArrayIfPresent(
      [String].self,
      forKey: .equipmentOverrides
    )
    dailyIntensityLevel = try container.decode(Int.self, forKey: .dailyIntensityLevel)
    lifeStressLevel = try container.decode(Int.self, forKey: .lifeStressLevel)
    recoverySpeed = try container.decode(Int.self, forKey: .recoverySpeed)
    sleepHours = try container.decode(Int.self, forKey: .sleepHours)
    injuries = try container.decodeArrayIfPresent([String].self, forKey: .injuries)
    bodyPartTags = try container.decodeArrayIfPresent([String].self, forKey: .bodyPartTags)
    musclesToStrengthen = try container.decodeArrayIfPresent(
      [String].self,
      forKey: .musclesToStrengthen
    )
    competitionTargeting = try container.decode(Bool.self, forKey: .competitionTargeting)
    competitionDate = try container.decodeIfPresent(Date.self, forKey: .competitionDate)
    targetWeightClass = try container.decodeIfPresent(String.self, forKey: .targetWeightClass)
    notesToCoach = try container.decodeIfPresent(String.self, forKey: .notesToCoach)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: EncodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(userID, forKey: .userID)
    try container.encode(trainingMode, forKey: .trainingMode)
    try container.encode(trainingYears, forKey: .trainingYears)
    try container.encode(squatStance, forKey: .squatStance)
    try container.encode(deadliftStance, forKey: .deadliftStance)
    try container.encodeIfPresent(benchGrip, forKey: .benchGrip)
    try container.encodeDecimalString(currentSquat1RM, forKey: .currentSquat1RM)
    try container.encodeDecimalString(bench1RM, forKey: .bench1RM)
    try container.encodeDecimalString(deadlift1RM, forKey: .deadlift1RM)
    try container.encode(trainingDaysOfWeek, forKey: .trainingDaysOfWeek)
    try container.encode(gymTier, forKey: .gymTier)
    try container.encode(equipmentOverrides, forKey: .equipmentOverrides)
    try container.encode(dailyIntensityLevel, forKey: .dailyIntensityLevel)
    try container.encode(lifeStressLevel, forKey: .lifeStressLevel)
    try container.encode(recoverySpeed, forKey: .recoverySpeed)
    try container.encode(sleepHours, forKey: .sleepHours)
    try container.encode(injuries, forKey: .injuries)
    try container.encode(bodyPartTags, forKey: .bodyPartTags)
    try container.encode(musclesToStrengthen, forKey: .musclesToStrengthen)
    try container.encode(competitionTargeting, forKey: .competitionTargeting)
    try container.encodeIfPresent(competitionDate, forKey: .competitionDate)
    try container.encodeIfPresent(targetWeightClass, forKey: .targetWeightClass)
    try container.encodeIfPresent(notesToCoach, forKey: .notesToCoach)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
  }

  private enum DecodingKeys: String, CodingKey {
    case id
    case userID = "userId"
    case trainingMode
    case trainingYears
    case squatStance
    case deadliftStance
    case benchGrip
    case currentSquat1RM = "currentSquat1Rm"
    case bench1RM = "bench1Rm"
    case deadlift1RM = "deadlift1Rm"
    case trainingDaysOfWeek
    case gymTier
    case equipmentOverrides
    case dailyIntensityLevel
    case lifeStressLevel
    case recoverySpeed
    case sleepHours
    case injuries
    case bodyPartTags
    case musclesToStrengthen
    case competitionTargeting
    case competitionDate
    case targetWeightClass
    case notesToCoach
    case createdAt
    case updatedAt
  }

  private enum EncodingKeys: String, CodingKey {
    case id
    case userID = "userId"
    case trainingMode
    case trainingYears
    case squatStance
    case deadliftStance
    case benchGrip
    case currentSquat1RM = "currentSquat_1rm"
    case bench1RM = "bench_1rm"
    case deadlift1RM = "deadlift_1rm"
    case trainingDaysOfWeek
    case gymTier
    case equipmentOverrides
    case dailyIntensityLevel
    case lifeStressLevel
    case recoverySpeed
    case sleepHours
    case injuries
    case bodyPartTags
    case musclesToStrengthen
    case competitionTargeting
    case competitionDate
    case targetWeightClass
    case notesToCoach
    case createdAt
    case updatedAt
  }
}
