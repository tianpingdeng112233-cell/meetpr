import Foundation

public struct PlanSet: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let planExerciseID: UUID
  public let setNumber: Int
  public let targetReps: Int
  public let targetRepsMax: Int?
  public let intensityMode: IntensityMode
  public let targetValue: Decimal
  public let loadMode: PlanLoadMode?
  public let targetPct: Decimal?
  public let percentageAnchor: PercentageAnchor?
  public let targetRPE: Decimal?
  public let rirTarget: Int?
  public let rpeLow: Decimal?
  public let rpeHigh: Decimal?
  public let weightLow: Decimal?
  public let weightHigh: Decimal?
  public let targetWeight: Decimal?
  public let setType: SetType
  public let restSeconds: Int?
  /// Student-visible coach cue carried alongside the set (spec 043 §G).
  /// Holds the original shorthand the parser could not structure into a number
  /// (e.g. 「70%top」「节奏3-1-0」「力竭」). `nil` for pre-043 data.
  public let coachNote: String?
  public let createdAt: Date

  public init(
    id: UUID,
    planExerciseID: UUID,
    setNumber: Int,
    targetReps: Int,
    targetRepsMax: Int? = nil,
    intensityMode: IntensityMode,
    targetValue: Decimal,
    loadMode: PlanLoadMode? = nil,
    targetPct: Decimal? = nil,
    percentageAnchor: PercentageAnchor? = nil,
    targetRPE: Decimal? = nil,
    rirTarget: Int? = nil,
    rpeLow: Decimal? = nil,
    rpeHigh: Decimal? = nil,
    weightLow: Decimal? = nil,
    weightHigh: Decimal? = nil,
    targetWeight: Decimal? = nil,
    setType: SetType,
    restSeconds: Int? = nil,
    coachNote: String? = nil,
    createdAt: Date
  ) {
    self.id = id
    self.planExerciseID = planExerciseID
    self.setNumber = setNumber
    self.targetReps = targetReps
    self.targetRepsMax = targetRepsMax
    self.intensityMode = intensityMode
    self.targetValue = targetValue
    self.loadMode = loadMode
    self.targetPct = targetPct
    self.percentageAnchor = percentageAnchor
    self.targetRPE = targetRPE
    self.rirTarget = rirTarget
    self.rpeLow = rpeLow
    self.rpeHigh = rpeHigh
    self.weightLow = weightLow
    self.weightHigh = weightHigh
    self.targetWeight = targetWeight
    self.setType = setType
    self.restSeconds = restSeconds
    self.coachNote = coachNote
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
    loadMode = try container.decodeIfPresent(PlanLoadMode.self, forKey: .loadMode)
    targetPct = try container.decodeDecimalIfPresent(forKey: .targetPct)
    percentageAnchor = PercentageAnchor(
      wireValue: try container.decodeIfPresent(String.self, forKey: .percentageAnchor)
    )
    targetRPE = try container.decodeDecimalIfPresent(forKey: .targetRPE)
    rirTarget = try container.decodeIfPresent(Int.self, forKey: .rirTarget)
    rpeLow = try container.decodeDecimalIfPresent(forKey: .rpeLow)
    rpeHigh = try container.decodeDecimalIfPresent(forKey: .rpeHigh)
    weightLow = try container.decodeDecimalIfPresent(forKey: .weightLow)
    weightHigh = try container.decodeDecimalIfPresent(forKey: .weightHigh)
    targetWeight = try container.decodeDecimalIfPresent(forKey: .targetWeight)
    setType = try container.decode(SetType.self, forKey: .setType)
    restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
    coachNote = try container.decodeIfPresent(String.self, forKey: .coachNote)
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
    try container.encodeIfPresent(loadMode, forKey: .loadMode)
    try container.encodeDecimalStringIfPresent(targetPct, forKey: .targetPct)
    try container.encodeIfPresent(percentageAnchor, forKey: .percentageAnchor)
    try container.encodeDecimalStringIfPresent(targetRPE, forKey: .targetRPE)
    try container.encodeIfPresent(rirTarget, forKey: .rirTarget)
    try container.encodeDecimalStringIfPresent(rpeLow, forKey: .rpeLow)
    try container.encodeDecimalStringIfPresent(rpeHigh, forKey: .rpeHigh)
    try container.encodeDecimalStringIfPresent(weightLow, forKey: .weightLow)
    try container.encodeDecimalStringIfPresent(weightHigh, forKey: .weightHigh)
    try container.encodeDecimalStringIfPresent(targetWeight, forKey: .targetWeight)
    try container.encode(setType, forKey: .setType)
    try container.encodeIfPresent(restSeconds, forKey: .restSeconds)
    try container.encodeIfPresent(coachNote, forKey: .coachNote)
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
    case loadMode
    case targetPct
    case percentageAnchor = "pctAnchor"
    // `convertFromSnakeCase` normalizes `target_rpe` to `targetRpe`.
    case targetRPE = "targetRpe"
    case rirTarget
    case rpeLow
    case rpeHigh
    case weightLow
    case weightHigh
    case targetWeight
    case setType
    case restSeconds
    case coachNote
    case createdAt
  }
}
