import Foundation

extension APIClient {
  public func submitReadiness(
    _ request: SubmitReadinessRequestDTO,
    accessToken: String
  ) async throws {
    let _: ReadinessCheckinDTO = try await post(
      path: "/students/me/readiness",
      body: request,
      accessToken: accessToken
    )
  }

  public func readinessCheckin(
    studentID: UUID,
    date: String,
    accessToken: String
  ) async throws -> ReadinessFetchResponseDTO {
    try await get(
      path: "/students/\(studentID.uuidString)/readiness",
      queryItems: [URLQueryItem(name: "date", value: date)],
      accessToken: accessToken
    )
  }
}
