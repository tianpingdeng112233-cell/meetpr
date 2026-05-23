import CoreModels
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
  public let profile: StudentProfile
  public let status: String

  public init(
    id: UUID,
    displayName: String,
    profile: StudentProfile,
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
