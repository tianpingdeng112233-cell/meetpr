import CoreModels
import Foundation
import Testing

@Test func coachFeedbackDecodesLegacyPayloadWithoutVideoFields() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000601",
      "coach_id": "00000000-0000-4000-8000-000000000602",
      "student_id": "00000000-0000-4000-8000-000000000603",
      "day_date": null,
      "plan_exercise_id": null,
      "text": "旧缓存",
      "posted_at": "2026-07-20T12:00:00Z",
      "read_at": null
    }
    """

  let feedback = try MeetPRCodec.decoder.decode(CoachFeedback.self, from: Data(json.utf8))

  #expect(feedback.videoID == nil)
  #expect(feedback.video == nil)
}

@Test func coachFeedbackVideoRoundTripPreservesMetadata() throws {
  let videoID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000604"))
  let loggedAt = try #require(
    Calendar(identifier: .iso8601).date(
      from: DateComponents(
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026,
        month: 7,
        day: 20,
        hour: 12
      )
    )
  )
  let feedback = CoachFeedback(
    id: UUID(),
    coachID: UUID(),
    studentID: UUID(),
    videoID: videoID,
    video: CoachFeedbackVideo(
      id: videoID,
      exerciseName: "暂停深蹲",
      setIndex: 2,
      weightKg: "125.00",
      reps: 5,
      loggedAt: loggedAt
    ),
    text: "底部保持张力",
    postedAt: loggedAt
  )

  let data = try MeetPRCodec.encoder.encode(feedback)
  let decoded = try MeetPRCodec.decoder.decode(CoachFeedback.self, from: data)

  #expect(decoded == feedback)
}
