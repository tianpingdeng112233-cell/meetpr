import CoreModels
import Foundation

extension APIClient {
  public func exercises(
    type: ExerciseType? = nil,
    accessToken: String
  ) async throws -> ExercisesResponseDTO {
    let queryItems =
      type.map { [URLQueryItem(name: "exercise_type", value: $0.rawValue)] } ?? []
    return try await get(path: "/exercises", queryItems: queryItems, accessToken: accessToken)
  }

  public func exerciseCatalogResponse(
    ifNoneMatch etag: String?,
    accessToken: String
  ) async throws -> APIResponse {
    let headers = etag.map { ["If-None-Match": $0] } ?? [:]
    return try await getResponse(
      path: "/exercises",
      accessToken: accessToken,
      headers: headers,
      additionalAcceptedStatusCodes: [304]
    )
  }
}
