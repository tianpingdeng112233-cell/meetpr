import Foundation

extension APIClient {
  public func allStudentSetLogs(
    studentID: UUID, from: String, endDate: String, accessToken: String
  ) async throws -> AllStudentSetLogsDTO {
    try await get(
      path: "/students/\(studentID.uuidString)/sets",
      queryItems: [
        URLQueryItem(name: "from", value: from), URLQueryItem(name: "to", value: endDate),
        URLQueryItem(name: "scope", value: "all"),
      ], accessToken: accessToken)
  }

  public func logStudentAddedSet(
    _ request: CreateStudentAddedSetRequestDTO, accessToken: String
  ) async throws -> CreateSetLogResponseDTO {
    try await post(path: "/sets/log", body: request, accessToken: accessToken)
  }

  public func deleteStudentAddedSet(id: UUID, accessToken: String) async throws {
    do {
      try await deleteNoContent(path: "/sets/\(id.uuidString)", accessToken: accessToken)
    } catch {
      guard BackendErrorEnvelope.machineCode(from: error) == "SET_NOT_FOUND" else { throw error }
    }
  }
}
