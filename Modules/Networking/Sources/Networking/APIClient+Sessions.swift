import Foundation

/// Backend spec 020 session projection. Snake-case keys and ISO timestamps are
/// handled by `MeetPRCodec`.
public struct TrainingSessionDTO: Codable, Equatable, Sendable {
  public let status: String
  public let startedAt: Date
  public let lastSetAt: Date
  public let completedAt: Date?
  public let durationSeconds: Int

  public init(
    status: String,
    startedAt: Date,
    lastSetAt: Date,
    completedAt: Date?,
    durationSeconds: Int
  ) {
    self.status = status
    self.startedAt = startedAt
    self.lastSetAt = lastSetAt
    self.completedAt = completedAt
    self.durationSeconds = durationSeconds
  }
}

public struct TrainingSessionResponseDTO: Codable, Equatable, Sendable {
  public let gymDay: String?
  public let session: TrainingSessionDTO?

  public init(gymDay: String?, session: TrainingSessionDTO?) {
    self.gymDay = gymDay
    self.session = session
  }
}

extension APIClient {
  /// POST /students/me/session/start — 200/201 both decode through the normal
  /// 2xx response path.
  public func startStudentSession(
    accessToken: String
  ) async throws -> TrainingSessionResponseDTO {
    try await post(path: "/students/me/session/start", accessToken: accessToken)
  }

  /// GET /students/me/session?date=YYYY-MM-DD.
  public func studentSession(
    date: String? = nil,
    accessToken: String
  ) async throws -> TrainingSessionResponseDTO {
    let queryItems = date.map { [URLQueryItem(name: "date", value: $0)] } ?? []
    return try await get(
      path: "/students/me/session",
      queryItems: queryItems,
      accessToken: accessToken
    )
  }
}
