import CoreModels
import Foundation

// Wire DTOs for the coach receive queue (spec 033; field names verbatim from
// backend spec 005 §endpoint B / handlers/coach-bind-requests.ts). The
// domain mapping to RepositoryContracts' CoachBindRequestItem lives in
// CoachKit — the Networking library stays contracts-free (031 precedent).

/// GET /coach/bind-requests — `{ "bind_requests": [...] }`.
public struct CoachBindRequestsResponseDTO: Codable, Equatable, Sendable {
  public let bindRequests: [CoachBindRequestItemDTO]

  public init(bindRequests: [CoachBindRequestItemDTO]) {
    self.bindRequests = bindRequests
  }
}

public struct CoachBindRequestItemDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let studentId: UUID
  public let displayName: String
  public let submittedAt: Date
  public let expiredAt: Date
  public let onboarding: CoachBindRequestOnboardingDTO

  public init(
    id: UUID,
    studentId: UUID,
    displayName: String,
    submittedAt: Date,
    expiredAt: Date,
    onboarding: CoachBindRequestOnboardingDTO
  ) {
    self.id = id
    self.studentId = studentId
    self.displayName = displayName
    self.submittedAt = submittedAt
    self.expiredAt = expiredAt
    self.onboarding = onboarding
  }
}

/// The queue item's 9-item onboarding summary. Decimal columns arrive as
/// strings ("180.00") → custom decode via `decodeDecimalIfPresent`; nullable
/// wire arrays decode as empty arrays. All product fields are null when the
/// onboarding row is missing (`completed` false).
public struct CoachBindRequestOnboardingDTO: Codable, Equatable, Sendable {
  public let completed: Bool
  public let gender: Gender?
  public let birthDate: String?
  public let weightKg: Decimal?
  public let trainingYears: Int?
  public let squat1RMKg: Decimal?
  public let bench1RMKg: Decimal?
  public let deadlift1RMKg: Decimal?
  public let muscleGroupsToStrengthen: [MuscleGroup]
  public let gymTier: GymTier?
  public let isCompeting: Bool?
  public let competitionDate: String?
  public let noteToCoach: String?
  public let uploadCount: Int

  public init(
    completed: Bool,
    gender: Gender?,
    birthDate: String?,
    weightKg: Decimal?,
    trainingYears: Int?,
    squat1RMKg: Decimal?,
    bench1RMKg: Decimal?,
    deadlift1RMKg: Decimal?,
    muscleGroupsToStrengthen: [MuscleGroup],
    gymTier: GymTier?,
    isCompeting: Bool?,
    competitionDate: String?,
    noteToCoach: String?,
    uploadCount: Int
  ) {
    self.completed = completed
    self.gender = gender
    self.birthDate = birthDate
    self.weightKg = weightKg
    self.trainingYears = trainingYears
    self.squat1RMKg = squat1RMKg
    self.bench1RMKg = bench1RMKg
    self.deadlift1RMKg = deadlift1RMKg
    self.muscleGroupsToStrengthen = muscleGroupsToStrengthen
    self.gymTier = gymTier
    self.isCompeting = isCompeting
    self.competitionDate = competitionDate
    self.noteToCoach = noteToCoach
    self.uploadCount = uploadCount
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    completed = try container.decode(Bool.self, forKey: .completed)
    gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
    birthDate = try container.decodeIfPresent(String.self, forKey: .birthDate)
    weightKg = try container.decodeDecimalIfPresent(forKey: .weightKg)
    trainingYears = try container.decodeIfPresent(Int.self, forKey: .trainingYears)
    squat1RMKg = try container.decodeDecimalIfPresent(forKey: .squat1RMKg)
    bench1RMKg = try container.decodeDecimalIfPresent(forKey: .bench1RMKg)
    deadlift1RMKg = try container.decodeDecimalIfPresent(forKey: .deadlift1RMKg)
    muscleGroupsToStrengthen = try container.decodeArrayIfPresent(
      [MuscleGroup].self, forKey: .muscleGroupsToStrengthen)
    gymTier = try container.decodeIfPresent(GymTier.self, forKey: .gymTier)
    isCompeting = try container.decodeIfPresent(Bool.self, forKey: .isCompeting)
    competitionDate = try container.decodeIfPresent(String.self, forKey: .competitionDate)
    noteToCoach = try container.decodeIfPresent(String.self, forKey: .noteToCoach)
    uploadCount = try container.decode(Int.self, forKey: .uploadCount)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(completed, forKey: .completed)
    try container.encodeIfPresent(gender, forKey: .gender)
    try container.encodeIfPresent(birthDate, forKey: .birthDate)
    try container.encodeDecimalStringIfPresent(weightKg, forKey: .weightKg)
    try container.encodeIfPresent(trainingYears, forKey: .trainingYears)
    try container.encodeDecimalStringIfPresent(squat1RMKg, forKey: .squat1RMKg)
    try container.encodeDecimalStringIfPresent(bench1RMKg, forKey: .bench1RMKg)
    try container.encodeDecimalStringIfPresent(deadlift1RMKg, forKey: .deadlift1RMKg)
    try container.encode(muscleGroupsToStrengthen, forKey: .muscleGroupsToStrengthen)
    try container.encodeIfPresent(gymTier, forKey: .gymTier)
    try container.encodeIfPresent(isCompeting, forKey: .isCompeting)
    try container.encodeIfPresent(competitionDate, forKey: .competitionDate)
    try container.encodeIfPresent(noteToCoach, forKey: .noteToCoach)
    try container.encode(uploadCount, forKey: .uploadCount)
  }

  /// Explicit post-conversion key names for the 1RM trio — same
  /// "squat1RmKg" quirk as OnboardingProfileDTO (convertFromSnakeCase turns
  /// `squat_1rm_kg` into "squat1RmKg").
  enum CodingKeys: String, CodingKey {
    case completed, gender, birthDate, weightKg, trainingYears
    case squat1RMKg = "squat1RmKg"
    case bench1RMKg = "bench1RmKg"
    case deadlift1RMKg = "deadlift1RmKg"
    case muscleGroupsToStrengthen, gymTier, isCompeting, competitionDate
    case noteToCoach, uploadCount
  }
}

/// POST /coach/bind-requests/:id/accept body.
public struct AcceptBindRequestRequestDTO: Encodable, Equatable, Sendable {
  /// Required online-backend wire contract. Keep this field and its fixed
  /// `true` value even though the client no longer exposes evaluation flows.
  public let skipEvaluation = true

  public init() {}

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(skipEvaluation, forKey: .skipEvaluation)
  }

  private enum CodingKeys: String, CodingKey {
    case skipEvaluation
  }
}

/// POST .../accept response. Retired and future response fields are ignored.
public struct AcceptBindRequestResponseDTO: Codable, Equatable, Sendable {
  public let bindRequest: BindRequestDTO

  public init(bindRequest: BindRequestDTO) {
    self.bindRequest = bindRequest
  }
}

/// POST .../reject response — `{ "bind_request": {...} }`.
public struct RejectBindRequestResponseDTO: Codable, Equatable, Sendable {
  public let bindRequest: BindRequestDTO

  public init(bindRequest: BindRequestDTO) {
    self.bindRequest = bindRequest
  }
}

/// The reject endpoint's `.strict()` empty-object body: any key is a 400, so
/// this encodes to exactly `{}`.
public struct EmptyObjectBodyDTO: Encodable, Equatable, Sendable {
  public init() {}

  public func encode(to encoder: Encoder) throws {
    _ = encoder.container(keyedBy: CodingKeys.self)
  }

  private enum CodingKeys: CodingKey {}
}
