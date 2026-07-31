import CoreModels
import Foundation
import Testing

@testable import Networking

@Test("video marker wire DTO decodes snake-case and maps to the domain")
func videoMarkerDecodingAndMapping() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000601",
      "video_id": "00000000-0000-4000-8000-000000000602",
      "coach_id": "00000000-0000-4000-8000-000000000603",
      "time_ms": 1250,
      "level": "warn",
      "note": "保持背部张力",
      "created_at": "2026-07-31T10:15:30Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(VideoMarkerDTO.self, from: Data(json.utf8))
  let marker = dto.toDomain()

  #expect(dto.videoID.uuidString == "00000000-0000-4000-8000-000000000602")
  #expect(dto.coachID.uuidString == "00000000-0000-4000-8000-000000000603")
  #expect(dto.timeMs == 1_250)
  #expect(marker.videoID == dto.videoID)
  #expect(marker.coachID == dto.coachID)
  #expect(marker.timeMilliseconds == 1_250)
  #expect(marker.level == .warn)
  #expect(marker.note == "保持背部张力")
}

@Test("video marker request and response encode through MeetPRCodec snake-case")
func videoMarkerEncodingUsesSharedCodec() throws {
  let videoID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000612"))
  let coachID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000613"))
  let markerID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000611"))
  let request = CreateVideoMarkerRequestDTO(timeMs: 2_500, level: .bad, note: "深度不足")
  let dto = VideoMarkerDTO(
    id: markerID,
    videoID: videoID,
    coachID: coachID,
    timeMs: request.timeMs,
    level: request.level,
    note: request.note,
    createdAt: Date(timeIntervalSince1970: 0)
  )

  let requestObject = try #require(
    JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(request)) as? [String: Any]
  )
  let responseObject = try #require(
    JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(dto)) as? [String: Any]
  )

  #expect(requestObject["time_ms"] as? Int == 2_500)
  #expect(requestObject["level"] as? String == "bad")
  #expect(requestObject["note"] as? String == "深度不足")
  #expect(requestObject["timeMs"] == nil)
  #expect(responseObject["video_id"] as? String == videoID.uuidString)
  #expect(responseObject["coach_id"] as? String == coachID.uuidString)
  #expect(responseObject["created_at"] != nil)
}

@Test("marker repository maps 404 and transport errors to unavailable, everything else to failed")
func markerRepositoryErrorClassification() {
  #expect(
    BackendVideoMarkerRepository.repositoryError(
      from: APIError.httpStatus(404, Data())
    ) == .unavailable
  )
  #expect(
    BackendVideoMarkerRepository.repositoryError(
      from: URLError(.notConnectedToInternet)
    ) == .unavailable
  )
  for status in [401, 403, 409, 500] {
    #expect(
      BackendVideoMarkerRepository.repositoryError(
        from: APIError.httpStatus(status, Data())
      ) == .failed
    )
  }
  struct Unknown: Error {}
  #expect(BackendVideoMarkerRepository.repositoryError(from: Unknown()) == .failed)
}
