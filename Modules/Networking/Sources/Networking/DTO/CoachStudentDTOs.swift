import Foundation

public struct CoachStudentsResponseDTO: Codable, Equatable, Sendable {
  public let students: [CoachStudentSummaryDTO]

  public init(students: [CoachStudentSummaryDTO]) {
    self.students = students
  }
}

public struct RenameCoachStudentRequestDTO: Codable, Equatable, Sendable {
  public let displayName: String

  public init(displayName: String) {
    self.displayName = displayName
  }
}

public struct CoachStudentRecentWeekDTO: Codable, Equatable, Sendable {
  public let trainedDays: Int
  public let plannedDays: Int

  public init(trainedDays: Int, plannedDays: Int) {
    self.trainedDays = trainedDays
    self.plannedDays = plannedDays
  }
}

/// GET /coach/students item. Real wire (handlers/coach-students.ts since
/// backend #9): `{ id, display_name, profile: { user_id, display_name,
/// created_at }, status, ... }` — the previous flat
/// `{ user_id, created_at }` decode never matched staging (drift fixed with
/// spec 033 D2). Decoding falls back to the flat keys defensively and ignores
/// retired or future response fields.
public struct CoachStudentSummaryDTO: Codable, Equatable, Sendable {
  public let userID: UUID
  public let displayName: String
  public let createdAt: Date
  public let status: String
  public let competitionDate: String?
  public let recentFourWeeks: [CoachStudentRecentWeekDTO]?

  public init(
    userID: UUID,
    displayName: String,
    createdAt: Date,
    status: String,
    competitionDate: String? = nil,
    recentFourWeeks: [CoachStudentRecentWeekDTO]? = nil
  ) {
    self.userID = userID
    self.displayName = displayName
    self.createdAt = createdAt
    self.status = status
    self.competitionDate = competitionDate
    self.recentFourWeeks = recentFourWeeks
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case userID = "userId"
    case displayName
    case createdAt
    case profile
    case status
    case competitionDate
    case recent4W
  }

  private struct ProfileDTO: Codable, Equatable, Sendable {
    let userId: UUID
    let displayName: String
    let createdAt: Date
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let profile = try container.decodeIfPresent(ProfileDTO.self, forKey: .profile)
    if let topLevelID = try container.decodeIfPresent(UUID.self, forKey: .id) {
      userID = topLevelID
    } else {
      userID = try container.decode(UUID.self, forKey: .userID)
    }
    displayName = try container.decode(String.self, forKey: .displayName)
    if let topLevelCreatedAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) {
      createdAt = topLevelCreatedAt
    } else if let profile {
      createdAt = profile.createdAt
    } else {
      throw DecodingError.keyNotFound(
        CodingKeys.createdAt,
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Neither created_at nor profile.created_at present."
        )
      )
    }
    status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
    competitionDate = try container.decodeIfPresent(String.self, forKey: .competitionDate)
    recentFourWeeks = try container.decodeIfPresent(
      [CoachStudentRecentWeekDTO].self,
      forKey: .recent4W
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(userID, forKey: .id)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(
      ProfileDTO(userId: userID, displayName: displayName, createdAt: createdAt),
      forKey: .profile
    )
    try container.encode(status, forKey: .status)
    try container.encodeIfPresent(competitionDate, forKey: .competitionDate)
    try container.encodeIfPresent(recentFourWeeks, forKey: .recent4W)
  }
}
