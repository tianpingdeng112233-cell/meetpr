import Foundation

/// Which rows `GET /students/:id/sets` returns (backend spec 010). `plan`
/// (server default) is the pre-spec-010 visible set; `all` adds adhoc and
/// orphaned rows, windowed on the client-local training day.
public enum SetLogFetchScope: String, Sendable {
  case plan
  case all
}

extension APIClient {
  public func logSet(
    _ request: CreateSetLogRequestDTO,
    accessToken: String
  ) async throws -> CreateSetLogResponseDTO {
    try await post(path: "/sets/log", body: request, accessToken: accessToken)
  }

  public func logAdhocSet(
    _ request: CreateAdhocSetLogRequestDTO,
    accessToken: String
  ) async throws -> CreateSetLogResponseDTO {
    try await post(path: "/sets/log", body: request, accessToken: accessToken)
  }

  public func studentSetLogs(
    studentID: UUID,
    from: Date,
    endDate: Date,
    scope: SetLogFetchScope? = nil,
    accessToken: String
  ) async throws -> SetLogsResponseDTO {
    try await studentSetLogs(
      studentID: studentID,
      from: WireFormatting.dateOnlyString(from: from),
      endDate: WireFormatting.dateOnlyString(from: endDate),
      scope: scope,
      accessToken: accessToken
    )
  }

  public func studentSetLogs(
    studentID: UUID,
    from: String,
    endDate: String,
    scope: SetLogFetchScope? = nil,
    accessToken: String
  ) async throws -> SetLogsResponseDTO {
    var queryItems = [
      URLQueryItem(name: "from", value: from),
      URLQueryItem(name: "to", value: endDate),
    ]
    if let scope {
      queryItems.append(URLQueryItem(name: "scope", value: scope.rawValue))
    }
    return try await get(
      path: "/students/\(studentID.uuidString)/sets",
      queryItems: queryItems,
      accessToken: accessToken
    )
  }
}
