import Foundation

public struct CoachStudentsResponseDTO: Codable, Equatable, Sendable {
  public let students: [CoachStudentSummaryDTO]

  public init(students: [CoachStudentSummaryDTO]) {
    self.students = students
  }

  // swiftlint:disable redundant_string_enum_value
  private enum CodingKeys: String, CodingKey {
    case students = "students"
  }
  // swiftlint:enable redundant_string_enum_value
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
    case id = "id"
    case displayName = "display_name"
    case profile = "profile"
    case status = "status"
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
    case userID = "user_id"
    case displayName = "display_name"
    case createdAt = "created_at"
  }
}
