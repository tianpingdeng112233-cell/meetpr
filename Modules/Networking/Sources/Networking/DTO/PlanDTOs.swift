import CoreModels
import Foundation

public struct PlanDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let coachID: UUID?
  public let traineeID: UUID
  public let name: String
  public let startDate: Date
  public let endDate: Date
  public let planWeeks: Int
  /// Decodes as `.regular` when absent (pre-033 fixtures).
  public let kind: PlanKind
  public let source: PlanSource
  public let sourceTemplateID: UUID?
  public let status: PlanStatus
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    coachID: UUID?,
    traineeID: UUID,
    name: String,
    startDate: Date,
    endDate: Date,
    planWeeks: Int,
    kind: PlanKind = .regular,
    source: PlanSource,
    sourceTemplateID: UUID? = nil,
    status: PlanStatus,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.coachID = coachID
    self.traineeID = traineeID
    self.name = name
    self.startDate = startDate
    self.endDate = endDate
    self.planWeeks = planWeeks
    self.kind = kind
    self.source = source
    self.sourceTemplateID = sourceTemplateID
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    coachID = try container.decodeIfPresent(UUID.self, forKey: .coachID)
    traineeID = try container.decode(UUID.self, forKey: .traineeID)
    name = try container.decode(String.self, forKey: .name)
    startDate = try container.decode(Date.self, forKey: .startDate)
    endDate = try container.decode(Date.self, forKey: .endDate)
    planWeeks = try container.decode(Int.self, forKey: .planWeeks)
    kind = try container.decodeIfPresent(PlanKind.self, forKey: .kind) ?? .regular
    source = try container.decode(PlanSource.self, forKey: .source)
    sourceTemplateID = try container.decodeIfPresent(UUID.self, forKey: .sourceTemplateID)
    status = try container.decode(PlanStatus.self, forKey: .status)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case coachID = "coachId"
    case traineeID = "traineeId"
    case name
    case startDate
    case endDate
    case planWeeks
    case kind
    case source
    case sourceTemplateID = "sourceTemplateId"
    case status
    case createdAt
    case updatedAt
  }
}

public struct PlansResponseDTO: Codable, Equatable, Sendable {
  public let plans: [PlanDTO]

  public init(plans: [PlanDTO]) {
    self.plans = plans
  }
}

public struct PlanWithChildrenDTO: Codable, Equatable, Sendable {
  public let plan: PlanDTO
  public let days: [PlanDayDTO]

  public init(plan: PlanDTO, days: [PlanDayDTO]) {
    self.plan = plan
    self.days = days
  }

  public init(from decoder: Decoder) throws {
    plan = try PlanDTO(from: decoder)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    days = try container.decodeIfPresent([PlanDayDTO].self, forKey: .days) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    try plan.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(days, forKey: .days)
  }

  private enum CodingKeys: String, CodingKey {
    case days
  }
}

public struct PlanDayDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let planID: UUID
  public let dayOfWeek: Int
  public let weekNumber: Int
  public let sortOrder: Int
  public let shiftedToDate: Date?
  public let exercises: [PlanExerciseDTO]

  public init(
    id: UUID,
    planID: UUID,
    dayOfWeek: Int,
    weekNumber: Int,
    sortOrder: Int,
    shiftedToDate: Date? = nil,
    exercises: [PlanExerciseDTO] = []
  ) {
    self.id = id
    self.planID = planID
    self.dayOfWeek = dayOfWeek
    self.weekNumber = weekNumber
    self.sortOrder = sortOrder
    self.shiftedToDate = shiftedToDate
    self.exercises = exercises
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case planID = "planId"
    case dayOfWeek
    case weekNumber
    case sortOrder
    case shiftedToDate
    case exercises
  }
}

public struct PlanExerciseDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let planDayID: UUID
  public let exerciseID: UUID
  public let isMainLift: Bool
  public let sortOrder: Int
  public let notes: String?
  public let sets: [PlanSetDTO]

  public init(
    id: UUID,
    planDayID: UUID,
    exerciseID: UUID,
    isMainLift: Bool,
    sortOrder: Int,
    notes: String? = nil,
    sets: [PlanSetDTO] = []
  ) {
    self.id = id
    self.planDayID = planDayID
    self.exerciseID = exerciseID
    self.isMainLift = isMainLift
    self.sortOrder = sortOrder
    self.notes = notes
    self.sets = sets
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case planDayID = "planDayId"
    case exerciseID = "exerciseId"
    case isMainLift
    case sortOrder
    case notes
    case sets
  }
}

public struct PlanSetDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let planExerciseID: UUID
  public let setNumber: Int
  public let targetReps: Int
  public let targetRepsMax: Int?
  public let intensityMode: IntensityMode
  public let targetValue: Decimal
  public let setType: SetType
  public let restSeconds: Int?
  /// Student-visible coach cue (spec 043 §G); `nil` from pre-043 backends.
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
    case setType
    case restSeconds
    case coachNote
    case createdAt
  }
}
