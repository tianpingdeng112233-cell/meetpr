import Foundation

public struct PlanSet: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let planExerciseID: UUID
  public let setNumber: Int
  public let targetReps: Int
  public let targetRepsMax: Int?
  public let intensityMode: IntensityMode
  public let targetValue: Decimal
  public let setType: SetType
  public let createdAt: Date

  public init(
    id: UUID,
    planExerciseID: UUID,
    setNumber: Int,
    targetReps: Int,
    targetRepsMax: Int? = nil,
    intensityMode: IntensityMode,
    targetValue: Decimal,
    setType: SetType,
    createdAt: Date
  ) {
    self.id = id
    self.planExerciseID = planExerciseID
    self.setNumber = setNumber
    self.targetReps = targetReps
    self.targetRepsMax = targetRepsMax
    self.intensityMode = intensityMode
    self.targetValue = targetValue
    self.setType = setType
    self.createdAt = createdAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    planExerciseID = try container.decode(UUID.self, forKey: .planExerciseID)
    setNumber = try container.decode(Int.self, forKey: .setNumber)
    targetReps = try container.decode(Int.self, forKey: .targetReps)
    targetRepsMax = try container.decodeIfPresent(Int.self, forKey: .targetRepsMax)
    intensityMode = try container.decode(IntensityMode.self, forKey: .intensityMode)
    targetValue = try container.decodeDecimal(forKey: .targetValue)
    setType = try container.decode(SetType.self, forKey: .setType)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(planExerciseID, forKey: .planExerciseID)
    try container.encode(setNumber, forKey: .setNumber)
    try container.encode(targetReps, forKey: .targetReps)
    try container.encodeIfPresent(targetRepsMax, forKey: .targetRepsMax)
    try container.encode(intensityMode, forKey: .intensityMode)
    try container.encodeDecimalString(targetValue, forKey: .targetValue)
    try container.encode(setType, forKey: .setType)
    try container.encode(createdAt, forKey: .createdAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case planExerciseID = "planExerciseId"
    case setNumber
    case targetReps
    case targetRepsMax
    case intensityMode
    case targetValue
    case setType
    case createdAt
  }
}
