import Foundation

public struct Exercise: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let name: String
  public let nameEn: String?
  public let exerciseType: ExerciseType
  public let mainLiftFamily: LiftFamily?
  public let isCompetitionLift: Bool
  public let muscleGroups: [MuscleGroup]
  public let equipment: [Equipment]
  public let movementPattern: [MovementPattern]
  public let createdByCoachID: UUID?
  public let createdAt: Date

  public init(
    id: UUID,
    name: String,
    nameEn: String? = nil,
    exerciseType: ExerciseType,
    mainLiftFamily: LiftFamily? = nil,
    isCompetitionLift: Bool,
    muscleGroups: [MuscleGroup],
    equipment: [Equipment],
    movementPattern: [MovementPattern] = [],
    createdByCoachID: UUID? = nil,
    createdAt: Date
  ) {
    self.id = id
    self.name = name
    self.nameEn = nameEn
    self.exerciseType = exerciseType
    self.mainLiftFamily = mainLiftFamily
    self.isCompetitionLift = isCompetitionLift
    self.muscleGroups = muscleGroups
    self.equipment = equipment
    self.movementPattern = movementPattern
    self.createdByCoachID = createdByCoachID
    self.createdAt = createdAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn)
    exerciseType = try container.decode(ExerciseType.self, forKey: .exerciseType)
    mainLiftFamily = try container.decodeIfPresent(LiftFamily.self, forKey: .mainLiftFamily)
    isCompetitionLift = try container.decode(Bool.self, forKey: .isCompetitionLift)
    muscleGroups = try container.decodeArrayIfPresent([MuscleGroup].self, forKey: .muscleGroups)
    equipment = try container.decodeArrayIfPresent([Equipment].self, forKey: .equipment)
    movementPattern = try container.decodeArrayIfPresent(
      [MovementPattern].self,
      forKey: .movementPattern
    )
    createdByCoachID = try container.decodeIfPresent(UUID.self, forKey: .createdByCoachID)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(nameEn, forKey: .nameEn)
    try container.encode(exerciseType, forKey: .exerciseType)
    try container.encodeIfPresent(mainLiftFamily, forKey: .mainLiftFamily)
    try container.encode(isCompetitionLift, forKey: .isCompetitionLift)
    try container.encode(muscleGroups, forKey: .muscleGroups)
    try container.encode(equipment, forKey: .equipment)
    try container.encode(movementPattern, forKey: .movementPattern)
    try container.encodeIfPresent(createdByCoachID, forKey: .createdByCoachID)
    try container.encode(createdAt, forKey: .createdAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case nameEn
    case exerciseType
    case mainLiftFamily
    case isCompetitionLift
    case muscleGroups
    case equipment
    case movementPattern
    case createdByCoachID = "createdByCoachId"
    case createdAt
  }
}
