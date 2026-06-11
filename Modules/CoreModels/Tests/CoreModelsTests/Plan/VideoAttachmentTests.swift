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
    uploadedAt: nil
  )

  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .iso8601
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601

  let decoded = try decoder.decode(VideoAttachment.self, from: encoder.encode(attachment))
  #expect(decoded == attachment)
}

@Test func videoAttachmentStatusRawValuesStayStable() {
  // Persisted JSON depends on these raw values; renaming a case breaks
  // recovery of older on-device records.
  #expect(VideoAttachment.Status.pending.rawValue == "pending")
  #expect(VideoAttachment.Status.uploading.rawValue == "uploading")
  #expect(VideoAttachment.Status.uploaded.rawValue == "uploaded")
  #expect(VideoAttachment.Status.failed.rawValue == "failed")
}
