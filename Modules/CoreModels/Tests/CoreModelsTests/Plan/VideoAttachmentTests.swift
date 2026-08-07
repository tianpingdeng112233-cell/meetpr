import Foundation
import Testing

@testable import CoreModels

@Test func videoAttachmentRoundTripsThroughJSON() throws {
  let attachment = VideoAttachment(
    id: UUID(),
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: UUID(),
    status: .uploading,
    contentType: "video/mp4",
    durationSeconds: 61.5,
    sizeBytes: 15_728_640,
    localFileName: "abc.mp4",
    recordedAt: Date(timeIntervalSince1970: 1_750_000_000),
    trainingDate: Date(timeIntervalSince1970: 1_749_916_800),
    uploadedAt: nil,
    uploadPartCount: 2,
    uploadPartTargets: [
      VideoUploadPartTarget(
        partNumber: 1,
        url: try #require(URL(string: "https://oss.test/part-1"))
      )
    ],
    uploadedParts: [VideoUploadedPart(partNumber: 1, etag: "etag-1")],
    uploadRetryCount: 2,
    firstUploadFailureAt: Date(timeIntervalSince1970: 1_750_000_010)
  )

  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .iso8601
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601

  let decoded = try decoder.decode(VideoAttachment.self, from: encoder.encode(attachment))
  #expect(decoded == attachment)
}

@Test func videoAttachmentDecodesRecordsWrittenBeforeBackgroundUploadMetadata() throws {
  let json = Data(
    #"""
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "setLogID": "00000000-0000-0000-0000-000000000002",
      "studentID": "00000000-0000-0000-0000-000000000003",
      "status": "uploading",
      "contentType": "video/mp4",
      "durationSeconds": 30,
      "sizeBytes": 1024,
      "localFileName": "legacy.mp4",
      "recordedAt": "2025-06-15T15:06:40Z"
    }
    """#.utf8
  )
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601

  let decoded = try decoder.decode(VideoAttachment.self, from: json)

  #expect(decoded.uploadPartCount == 0)
  #expect(decoded.uploadPartTargets.isEmpty)
  #expect(decoded.uploadedParts.isEmpty)
  #expect(decoded.uploadRetryCount == 0)
  #expect(decoded.firstUploadFailureAt == nil)
  #expect(decoded.trainingDate == decoded.recordedAt)
}

@Test func videoAttachmentStatusRawValuesStayStable() {
  // Persisted JSON depends on these raw values; renaming a case breaks
  // recovery of older on-device records.
  #expect(VideoAttachment.Status.pending.rawValue == "pending")
  #expect(VideoAttachment.Status.uploading.rawValue == "uploading")
  #expect(VideoAttachment.Status.uploaded.rawValue == "uploaded")
  #expect(VideoAttachment.Status.failed.rawValue == "failed")
}
