import Foundation

extension APIClient {
  /// `GET /students/:id/videos` — the coach-side video wall (spec 029 second
  /// pass). Metadata only, newest-first, capped server-side; playback goes
  /// through `GET /uploads/:id/url` per item (see `attachmentURL`).
  public func studentVideos(
    studentID: UUID,
    accessToken: String
  ) async throws -> StudentVideosResponseDTO {
    try await get(
      path: "/students/\(studentID.uuidString)/videos",
      accessToken: accessToken
    )
  }
}
