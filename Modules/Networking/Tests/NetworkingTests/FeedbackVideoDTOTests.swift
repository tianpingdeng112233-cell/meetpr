import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func feedbackDTODecodesAndMapsLinkedVideo() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000211",
      "coach_id": "00000000-0000-4000-8000-000000000212",
      "student_id": "00000000-0000-4000-8000-000000000213",
      "day_date": "2026-07-20",
      "plan_exercise_id": "00000000-0000-4000-8000-000000000214",
      "video_id": "00000000-0000-4000-8000-000000000215",
      "video": {
        "id": "00000000-0000-4000-8000-000000000215",
        "exercise_name": "暂停深蹲",
        "exercise_name_en": "Pause Squat",
        "set_index": 2,
        "weight_kg": "125.00",
        "reps": 5,
        "logged_at": "2026-07-20T12:00:00Z"
      },
      "text": "底部保持张力",
      "posted_at": "2026-07-20T13:00:00Z",
      "read_at": null
    }
    """

  let dto = try MeetPRCodec.decoder.decode(FeedbackDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(domain.videoID?.uuidString == "00000000-0000-4000-8000-000000000215")
  #expect(domain.video?.exerciseName == "暂停深蹲")
  #expect(domain.video?.exerciseNameEn == "Pause Squat")
  #expect(domain.video?.setIndex == 2)
  #expect(domain.video?.weightKg == "125.00")
  #expect(domain.video?.reps == 5)
}

/// A freely recorded clip (uploaded with no `set_log_id`, which spec 025 allows
/// feedback on) resolves every left-joined field to null. If any of them were
/// non-optional the whole `items` array would fail to decode and the student's
/// inbox would go blank — so this guards far more than one card.
@Test func feedbackDTODecodesVideoWithNoSetLogMetadata() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000221",
      "coach_id": "00000000-0000-4000-8000-000000000222",
      "student_id": "00000000-0000-4000-8000-000000000223",
      "day_date": null,
      "plan_exercise_id": null,
      "video_id": "00000000-0000-4000-8000-000000000225",
      "video": {
        "id": "00000000-0000-4000-8000-000000000225",
        "exercise_name": null,
        "set_index": null,
        "weight_kg": null,
        "reps": null,
        "logged_at": null
      },
      "text": "这条随手拍的也说一句",
      "posted_at": "2026-07-20T13:00:00Z",
      "read_at": null
    }
    """

  let domain = try MeetPRCodec.decoder.decode(FeedbackDTO.self, from: Data(json.utf8)).toDomain()

  #expect(domain.video?.id.uuidString == "00000000-0000-4000-8000-000000000225")
  #expect(domain.video?.exerciseName == nil)
  #expect(domain.video?.exerciseNameEn == nil)
  #expect(domain.video?.setIndex == nil)
  #expect(domain.video?.weightKg == nil)
  #expect(domain.video?.reps == nil)
  #expect(domain.video?.loggedAt == nil)
}

@Test func feedbackDTODecodesDeletedLinkedVideo() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000221",
      "coach_id": "00000000-0000-4000-8000-000000000222",
      "student_id": "00000000-0000-4000-8000-000000000223",
      "day_date": null,
      "plan_exercise_id": null,
      "video_id": "00000000-0000-4000-8000-000000000224",
      "video": null,
      "text": "视频已删除",
      "posted_at": "2026-07-20T13:00:00Z",
      "read_at": null
    }
    """

  let domain = try MeetPRCodec.decoder.decode(FeedbackDTO.self, from: Data(json.utf8)).toDomain()

  #expect(domain.videoID?.uuidString == "00000000-0000-4000-8000-000000000224")
  #expect(domain.video == nil)
}

@Test func createFeedbackRequestEncodesVideoIDAsSnakeCase() throws {
  let studentID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000302"))
  let videoID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000303"))
  let request = CreateFeedbackRequestDTO(
    studentID: studentID,
    dayDate: "2026-07-20",
    videoID: videoID,
    text: "Nice work."
  )

  let data = try MeetPRCodec.encoder.encode(request)
  let json = try #require(String(data: data, encoding: .utf8))

  #expect(json.contains(#""video_id":"00000000-0000-4000-8000-000000000303""#))
}

@Test func feedbackCacheLoadsLegacyEntriesWithoutVideoFields() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "NetworkingTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  let studentID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000411"))
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let fileURL = directory.appending(path: "student-\(studentID.uuidString)-feedback.json")
  let json = """
    [{
      "id": "00000000-0000-4000-8000-000000000412",
      "coach_id": "00000000-0000-4000-8000-000000000413",
      "student_id": "00000000-0000-4000-8000-000000000411",
      "day_date": null,
      "plan_exercise_id": null,
      "text": "缓存反馈",
      "posted_at": "2026-07-20T12:00:00Z",
      "read_at": null
    }]
    """
  try Data(json.utf8).write(to: fileURL)

  let cached = await FeedbackCache(directory: directory).loadFeedback(studentID: studentID)

  #expect(cached?.count == 1)
  #expect(cached?.first?.videoID == nil)
  #expect(cached?.first?.video == nil)
  #expect(FileManager.default.fileExists(atPath: fileURL.path))
}
