import Foundation

public struct CoachStudentsResponseDTO: Codable, Equatable, Sendable {
  public let students: [CoachStudentSummaryDTO]

  public init(students: [CoachStudentSummaryDTO]) {
    self.students = students
  }
}

public struct CoachStudentSummaryDTO: Codable, Equatable, Sendable {
  public let userID: UUID
  public let displayName: String
  public let createdAt: Date
  public let status: String

  public init(
    userID: UUID,
    displayName: String,
    createdAt: Date,
    status: String
  ) {
    self.userID = userID
    self.displayName = displayName
    self.createdAt = createdAt
    self.status = status
  }

  private enum CodingKeys: String, CodingKey {
    case userID = "userId"
    case displayName
    case createdAt
    case status
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    userID = try container.decode(UUID.self, forKey: .userID)
    displayName = try container.decode(String.self, forKey: .displayName)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
  }
}
