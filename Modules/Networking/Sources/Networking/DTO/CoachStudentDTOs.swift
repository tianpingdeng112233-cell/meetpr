import Foundation

public struct CoachStudentsResponseDTO: Codable, Equatable, Sendable {
  public let students: [CoachStudentSummaryDTO]

  public init(students: [CoachStudentSummaryDTO]) {
    self.students = students
  }
}

public struct CoachStudentSummaryDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let displayName: String
  public let profile: CoachStudentProfileDTO
  public let status: String

  public init(
    id: UUID,
    displayName: String,
    profile: CoachStudentProfileDTO,
    status: String
  ) {
    self.id = id
    self.displayName = displayName
    self.profile = profile
    self.status = status
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case displayName
    case profile
    case status
  }
}

public struct CoachStudentProfileDTO: Codable, Equatable, Sendable {
  public let userID: UUID
  public let displayName: String
  public let createdAt: Date

  public init(userID: UUID, displayName: String, createdAt: Date) {
    self.userID = userID
    self.displayName = displayName
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {
    case userID = "userId"
    case displayName
    case createdAt
  }
}
