import Foundation

extension APIClient {
  public func coachStudents(accessToken: String) async throws -> CoachStudentsResponseDTO {
    try await get(path: "/coach/students", accessToken: accessToken)
  }
}
