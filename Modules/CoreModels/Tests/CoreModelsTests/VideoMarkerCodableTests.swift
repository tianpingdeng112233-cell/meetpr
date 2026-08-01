import Foundation
import Testing

@testable import CoreModels

@Test("video marker annotation fields decode through the shared snake-case codec")
func videoMarkerAnnotationFieldsDecode() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000641",
      "video_id": "00000000-0000-4000-8000-000000000642",
      "coach_id": "00000000-0000-4000-8000-000000000643",
      "time_milliseconds": 2800,
      "level": "info",
      "note": "保持核心收紧",
      "created_at": "2026-08-01T10:15:30Z",
      "attachment_id": "00000000-0000-4000-8000-000000000644",
      "annotation_url": "https://cdn.example.com/annotations/frame.png",
      "annotation_expires_in": 900
    }
    """

  let marker = try MeetPRCodec.decoder.decode(VideoMarker.self, from: Data(json.utf8))

  #expect(marker.videoID.uuidString == "00000000-0000-4000-8000-000000000642")
  #expect(marker.coachID.uuidString == "00000000-0000-4000-8000-000000000643")
  #expect(marker.attachmentID?.uuidString == "00000000-0000-4000-8000-000000000644")
  #expect(marker.annotationURL?.absoluteString == "https://cdn.example.com/annotations/frame.png")
  #expect(marker.annotationExpiresIn == 900)
}

@Test("legacy video markers decode with absent annotation fields")
func legacyVideoMarkerAnnotationFieldsDefaultToNil() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000651",
      "video_id": "00000000-0000-4000-8000-000000000652",
      "coach_id": "00000000-0000-4000-8000-000000000653",
      "time_milliseconds": 6400,
      "level": "warn",
      "note": "注意动作深度",
      "created_at": "2026-08-01T10:15:30Z"
    }
    """

  let marker = try MeetPRCodec.decoder.decode(VideoMarker.self, from: Data(json.utf8))

  #expect(marker.attachmentID == nil)
  #expect(marker.annotationURL == nil)
  #expect(marker.annotationExpiresIn == nil)
}
