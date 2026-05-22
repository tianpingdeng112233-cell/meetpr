import CoreModels
import Foundation

public struct CreatePlanRequestDTO: Encodable, Equatable, Sendable {
  public let traineeID: UUID
  public let name: String
  public let startDate: String
  public let endDate: String
  public let planWeeks: Int
  public let source: PlanSource
  public let sourceTemplateID: UUID?

  public init(
    traineeID: UUID,
    name: String,
    startDate: Date,
    endDate: Date,
    planWeeks: Int,
    source: PlanSource,
    sourceTemplateID: UUID? = nil
  ) {
    self.traineeID = traineeID
    self.name = name
    self.startDate = WireFormatting.dateOnlyString(from: startDate)
    self.endDate = WireFormatting.dateOnlyString(from: endDate)
    self.planWeeks = planWeeks
    self.source = source
    self.sourceTemplateID = sourceTemplateID
  }

  public init(
    traineeID: UUID,
    name: String,
    startDate: String,
    endDate: String,
    planWeeks: Int,
    source: PlanSource,
    sourceTemplateID: UUID? = nil
  ) {
    self.traineeID = traineeID
    self.name = name
    self.startDate = startDate
    self.endDate = endDate
    self.planWeeks = planWeeks
    self.source = source
    self.sourceTemplateID = sourceTemplateID
  }

  private enum CodingKeys: String, CodingKey {
    case traineeID = "trainee_id"
    case name = "name"
    case startDate = "start_date"
    case endDate = "end_date"
    case planWeeks = "plan_weeks"
    case source = "source"
    case sourceTemplateID = "source_template_id"
  }
}

public struct PlanDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let coachID: UUID
  public let traineeID: UUID
  public let name: String
  public let startDate: Date
  public let endDate: Date
  public let planWeeks: Int
  public let source: PlanSource
  public let sourceTemplateID: UUID?
  public let status: PlanStatus
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    coachID: UUID,
    traineeID: UUID,
    name: String,
    startDate: Date,
    endDate: Date,
    planWeeks: Int,
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
    self.source = source
    self.sourceTemplateID = sourceTemplateID
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(coachID, forKey: .coachID)
    try container.encode(traineeID, forKey: .traineeID)
    try container.encode(name, forKey: .name)
    try container.encode(WireFormatting.dateOnlyString(from: startDate), forKey: .startDate)
    try container.encode(WireFormatting.dateOnlyString(from: endDate), forKey: .endDate)
    try container.encode(planWeeks, forKey: .planWeeks)
    try container.encode(source, forKey: .source)
    try container.encodeIfPresent(sourceTemplateID, forKey: .sourceTemplateID)
    try container.encode(status, forKey: .status)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case coachID = "coach_id"
    case traineeID = "trainee_id"
    case name = "name"
    case startDate = "start_date"
    case endDate = "end_date"
    case planWeeks = "plan_weeks"
    case source = "source"
    case sourceTemplateID = "source_template_id"
    case status = "status"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

public struct PlansResponseDTO: Codable, Equatable, Sendable {
  public let plans: [PlanDTO]

  public init(plans: [PlanDTO]) {
    self.plans = plans
  }

  // swiftlint:disable redundant_string_enum_value
  private enum CodingKeys: String, CodingKey {
    case plans = "plans"
  }
  // swiftlint:enable redundant_string_enum_value
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

  // swiftlint:disable redundant_string_enum_value
  private enum CodingKeys: String, CodingKey {
    case days = "days"
  }
  // swiftlint:enable redundant_string_enum_value
}

public struct PlanDayDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let planID: UUID
  public let dayOfWeek: Int
  public let weekNumber: Int
  public let sortOrder: Int
  public let exercises: [PlanExerciseDTO]

  public init(
    id: UUID,
    planID: UUID,
    dayOfWeek: Int,
    weekNumber: Int,
    sortOrder: Int,
    exercises: [PlanExerciseDTO] = []
  ) {
    self.id = id
    self.planID = planID
    self.dayOfWeek = dayOfWeek
    self.weekNumber = weekNumber
    self.sortOrder = sortOrder
    self.exercises = exercises
  }

  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case planID = "plan_id"
    case dayOfWeek = "day_of_week"
    case weekNumber = "week_number"
    case sortOrder = "sort_order"
    case exercises = "exercises"
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
    case id = "id"
    case planDayID = "plan_day_id"
    case exerciseID = "exercise_id"
    case isMainLift = "is_main_lift"
    case sortOrder = "sort_order"
    case notes = "notes"
    case sets = "sets"
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
    case id = "id"
    case planExerciseID = "plan_exercise_id"
    case setNumber = "set_number"
    case targetReps = "target_reps"
    case targetRepsMax = "target_reps_max"
    case intensityMode = "intensity_mode"
    case targetValue = "target_value"
    case setType = "set_type"
    case createdAt = "created_at"
  }
}
