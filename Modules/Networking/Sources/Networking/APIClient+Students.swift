import Foundation

extension APIClient {
  public func coachStudents(accessToken: String) async throws -> CoachStudentsResponseDTO {
    try await get(path: "/coach/students", accessToken: accessToken)
  }

  public func renameCoachStudent(
    id: UUID,
    displayName: String,
    accessToken: String
  ) async throws -> CoachStudentSummaryDTO {
    try await patch(
      path: "/coach/students/\(id.uuidString)",
      body: RenameCoachStudentRequestDTO(displayName: displayName),
      accessToken: accessToken
    )
  }
}
