import CoreModels
import Foundation

public struct CreatePlanRequestDTO: Encodable, Equatable, Sendable {
  public let traineeID: UUID
  public let name: String
  public let startDate: String
  public let endDate: String
  public let planWeeks: Int
  /// Always sent explicitly ("regular" / "adaptation"), never left to the
  /// backend default — explicit wire beats implicit (spec 033 D9).
  public let kind: PlanKind
  public let source: PlanSource
  public let sourceTemplateID: UUID?

  public init(
    traineeID: UUID,
    name: String,
    startDate: Date,
    endDate: Date,
    planWeeks: Int,
    kind: PlanKind = .regular,
    source: PlanSource,
    sourceTemplateID: UUID? = nil
  ) {
    self.traineeID = traineeID
    self.name = name
    self.startDate = WireFormatting.dateOnlyString(from: startDate)
    self.endDate = WireFormatting.dateOnlyString(from: endDate)
    self.planWeeks = planWeeks
    self.kind = kind
    self.source = source
    self.sourceTemplateID = sourceTemplateID
  }

  public init(
    traineeID: UUID,
    name: String,
    startDate: String,
    endDate: String,
    planWeeks: Int,
    kind: PlanKind = .regular,
    source: PlanSource,
    sourceTemplateID: UUID? = nil
  ) {
    self.traineeID = traineeID
    self.name = name
    self.startDate = startDate
    self.endDate = endDate
    self.planWeeks = planWeeks
    self.kind = kind
    self.source = source
    self.sourceTemplateID = sourceTemplateID
  }

  private enum CodingKeys: String, CodingKey {
    case traineeID = "traineeId"
    case name
    case startDate
    case endDate
    case planWeeks
    case kind
    case source
    case sourceTemplateID = "sourceTemplateId"
  }
}

public struct CreatePlanDayRequestDTO: Encodable, Equatable, Sendable {
  public let dayOfWeek: Int
  public let weekNumber: Int
  public let sortOrder: Int

  public init(dayOfWeek: Int, weekNumber: Int, sortOrder: Int) {
    self.dayOfWeek = dayOfWeek
    self.weekNumber = weekNumber
    self.sortOrder = sortOrder
  }
}

public struct CreatePlanExerciseRequestDTO: Encodable, Equatable, Sendable {
  public let exerciseID: UUID
  public let isMainLift: Bool
  public let sortOrder: Int
  public let notes: String?

  public init(
    exerciseID: UUID,
    isMainLift: Bool,
    sortOrder: Int,
    notes: String? = nil
  ) {
    self.exerciseID = exerciseID
    self.isMainLift = isMainLift
    self.sortOrder = sortOrder
    self.notes = notes
  }

  private enum CodingKeys: String, CodingKey {
    case exerciseID = "exerciseId"
    case isMainLift
    case sortOrder
    case notes
  }
}

public struct CreatePlanSetRequestDTO: Encodable, Equatable, Sendable {
  public let setNumber: Int
  public let targetReps: Int
  public let targetRepsMax: Int?
  public let intensityMode: IntensityMode
  public let targetValue: Decimal
  public let setType: SetType

  public init(
    setNumber: Int,
    targetReps: Int,
    targetRepsMax: Int? = nil,
    intensityMode: IntensityMode,
    targetValue: Decimal,
    setType: SetType
  ) {
    self.setNumber = setNumber
    self.targetReps = targetReps
    self.targetRepsMax = targetRepsMax
    self.intensityMode = intensityMode
    self.targetValue = targetValue
    self.setType = setType
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(setNumber, forKey: .setNumber)
    try container.encode(targetReps, forKey: .targetReps)
    try container.encodeIfPresent(targetRepsMax, forKey: .targetRepsMax)
    try container.encode(intensityMode, forKey: .intensityMode)
    try container.encode(Self.targetValueString(from: targetValue), forKey: .targetValue)
    try container.encode(setType, forKey: .setType)
  }

  private static func targetValueString(from decimal: Decimal) -> String {
    var value = decimal
    var rounded = Decimal()
    NSDecimalRound(&rounded, &value, 2, .plain)
    return NSDecimalNumber(decimal: rounded).stringValue
  }

  private enum CodingKeys: String, CodingKey {
    case setNumber
    case targetReps
    case targetRepsMax
    case intensityMode
    case targetValue
    case setType
  }
}
