import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func coachStudentsContractDecodesBackendSummaryShape() throws {
  let json = """
    {
      "students": [
        {
          "user_id": "00000000-0000-4000-8000-000000000301",
          "display_name": "xty",
          "created_at": "2026-05-22T10:27:16.254Z"
        }
      ]
    }
    """

  let response = try MeetPRCodec.decoder.decode(
    CoachStudentsResponseDTO.self,
    from: Data(json.utf8)
  )
  let student = try #require(response.students.first)
  let expectedUserID = try uuid("00000000-0000-4000-8000-000000000301")
  let expectedCreatedAt = try isoDate("2026-05-22T10:27:16.254Z")

  #expect(student.userID == expectedUserID)
  #expect(student.displayName == "xty")
  #expect(student.createdAt == expectedCreatedAt)
  #expect(student.status == "active")
}

@Test func plansContractDecodesNullCoachID() throws {
  let json = """
    {
      "plans": [
        {
          "id": "00000000-0000-4000-8000-000000000401",
          "coach_id": null,
          "trainee_id": "00000000-0000-4000-8000-000000000402",
          "name": "Self training cycle",
          "start_date": "2026-05-22",
          "end_date": "2026-06-18",
          "plan_weeks": 4,
          "source": "algorithm",
          "source_template_id": null,
          "status": "draft",
          "created_at": "2026-05-22T10:27:16.254Z",
          "updated_at": "2026-05-22T10:27:16.254Z"
        }
      ]
    }
    """

  let response = try MeetPRCodec.decoder.decode(PlansResponseDTO.self, from: Data(json.utf8))
  let dto = try #require(response.plans.first)
  let domain = dto.toDomain()
  let expectedCreatedAt = try isoDate("2026-05-22T10:27:16.254Z")

  #expect(dto.coachID == nil)
  #expect(domain.coachID == nil)
  #expect(dto.createdAt == expectedCreatedAt)
}

@Test func authContractDecodesSnakeCaseTokensAndFractionalCreatedAt() throws {
  let json = """
    {
      "user": {
        "id": "00000000-0000-4000-8000-000000000501",
        "phone": "+8613800000001",
        "role": "coach",
        "created_at": "2026-05-22T10:27:16.254Z"
      },
      "access_token": "access-token",
      "refresh_token": "refresh-token"
    }
    """

  let response = try MeetPRCodec.decoder.decode(AuthResultDTO.self, from: Data(json.utf8))
  let user = try response.user.toUser()
  let expectedCreatedAt = try isoDate("2026-05-22T10:27:16.254Z")

  #expect(response.accessToken == "access-token")
  #expect(response.refreshToken == "refresh-token")
  #expect(user.createdAt == expectedCreatedAt)
  #expect(user.updatedAt == user.createdAt)
}

private func uuid(_ rawValue: String) throws -> UUID {
  try #require(UUID(uuidString: rawValue))
}

private func isoDate(_ rawValue: String) throws -> Date {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return try #require(formatter.date(from: rawValue))
}

@Test func studentVideosContractDecodesLinkedAndUnlinkedItems() throws {
  let json = """
    {
      "videos": [
        {
          "id": "00000000-0000-4000-8000-000000000601",
          "set_log_id": "00000000-0000-4000-8000-000000000602",
          "plan_exercise_id": "00000000-0000-4000-8000-000000000603",
          "content_type": "video/mp4",
          "size_bytes": 15728640,
          "filename": "setlog.mp4",
          "created_at": "2026-05-22T10:27:16.254Z",
          "logged_at": "2026-05-22T09:30:00.000Z"
        },
        {
          "id": "00000000-0000-4000-8000-000000000604",
          "set_log_id": null,
          "plan_exercise_id": null,
          "content_type": "video/quicktime",
          "size_bytes": 1048576,
          "filename": null,
          "created_at": "2026-05-21T08:00:00.000Z",
          "logged_at": null
        }
      ]
    }
    """

  let response = try MeetPRCodec.decoder.decode(
    StudentVideosResponseDTO.self,
    from: Data(json.utf8)
  )
  #expect(response.videos.count == 2)

  let linked = try #require(response.videos.first).toDomain()
  #expect(linked.id == (try uuid("00000000-0000-4000-8000-000000000601")))
  #expect(linked.setLogID == (try uuid("00000000-0000-4000-8000-000000000602")))
  #expect(linked.planExerciseID == (try uuid("00000000-0000-4000-8000-000000000603")))
  #expect(linked.sizeBytes == 15_728_640)
  #expect(linked.loggedAt == (try isoDate("2026-05-22T09:30:00.000Z")))
  // Linked videos group by the training day, not the upload day.
  #expect(linked.displayDate == (try isoDate("2026-05-22T09:30:00.000Z")))

  let unlinked = try #require(response.videos.last).toDomain()
  #expect(unlinked.setLogID == nil)
  #expect(unlinked.planExerciseID == nil)
  #expect(unlinked.filename == nil)
  #expect(unlinked.loggedAt == nil)
  // Unlinked uploads fall back to the upload timestamp.
  #expect(unlinked.displayDate == (try isoDate("2026-05-21T08:00:00.000Z")))
}
