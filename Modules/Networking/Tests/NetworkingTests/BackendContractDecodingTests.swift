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
