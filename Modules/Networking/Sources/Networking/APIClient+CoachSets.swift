import Foundation

extension APIClient {
  public func coachSetLogs(
    studentID: UUID,
    from: Date,
    endDate: Date,
    accessToken: String
  ) async throws -> CoachSetLogsResponseDTO {
    try await get(
      path: "/students/\(studentID.uuidString)/sets",
      queryItems: [
        URLQueryItem(name: "from", value: WireFormatting.dateOnlyString(from: from)),
        URLQueryItem(
          name: "to", value: WireFormatting.exclusiveEndDateOnlyString(closedUpperBound: endDate)),
        URLQueryItem(name: "scope", value: "all"),
      ],
      accessToken: accessToken
    )
  }
}
