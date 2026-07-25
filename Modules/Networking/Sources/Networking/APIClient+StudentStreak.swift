import Foundation

extension APIClient {
  public func studentStreak(accessToken: String) async throws -> StudentStreakResponseDTO {
    try await get(
      path: "/students/me/streak",
      accessToken: accessToken
    )
  }
}
