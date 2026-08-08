import Foundation

extension APIClient {
  public func logSet(
    _ request: CreateSetLogRequestDTO,
    accessToken: String
  ) async throws -> CreateSetLogResponseDTO {
    try await post(path: "/sets/log", body: request, accessToken: accessToken)
  }

  public func studentSetLogs(
    studentID: UUID,
    from: Date,
    endDate: Date,
    accessToken: String
  ) async throws -> SetLogsResponseDTO {
    try await studentSetLogs(
      studentID: studentID,
      from: WireFormatting.dateOnlyString(from: from),
      endDate: WireFormatting.dateOnlyString(from: endDate),
      accessToken: accessToken
    )
  }

  public func studentSetLogs(
    studentID: UUID,
    from: String,
    endDate: String,
    accessToken: String
  ) async throws -> SetLogsResponseDTO {
    try await get(
      path: "/students/\(studentID.uuidString)/sets",
      queryItems: [
        URLQueryItem(name: "from", value: from),
        URLQueryItem(name: "to", value: endDate),
        URLQueryItem(name: "scope", value: "plan"),
      ],
      accessToken: accessToken
    )
  }
}
