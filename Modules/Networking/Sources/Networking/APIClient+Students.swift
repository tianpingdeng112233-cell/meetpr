import Foundation

extension APIClient {
  public func coachStudents(accessToken: String) async throws -> CoachStudentsResponseDTO {
    try await get(path: "/coach/students", accessToken: accessToken)
  }

  public func coachStudentExerciseStats(
    studentID: UUID,
    accessToken: String
  ) async throws -> CoachExerciseStatsResponseDTO {
    try await get(
      path: "/coach/students/\(studentID.uuidString)/exercise-stats",
      accessToken: accessToken
    )
  }
}
