import Foundation

extension APIClient {
  public func videoMarkers(
    videoID: UUID,
    accessToken: String
  ) async throws -> VideoMarkersResponseDTO {
    try await get(
      path: "/videos/\(videoID.uuidString)/markers",
      accessToken: accessToken
    )
  }

  public func createVideoMarker(
    videoID: UUID,
    body: CreateVideoMarkerRequestDTO,
    accessToken: String
  ) async throws -> VideoMarkerDTO {
    try await post(
      path: "/videos/\(videoID.uuidString)/markers",
      body: body,
      accessToken: accessToken
    )
  }

  public func deleteVideoMarker(
    videoID: UUID,
    markerID: UUID,
    accessToken: String
  ) async throws {
    try await deleteNoContent(
      path: "/videos/\(videoID.uuidString)/markers/\(markerID.uuidString)",
      accessToken: accessToken
    )
  }
}
