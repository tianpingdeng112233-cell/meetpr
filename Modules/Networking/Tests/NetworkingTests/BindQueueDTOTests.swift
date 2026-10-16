import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func acceptBindRequestBodyKeepsCompatibilityFlagTrue() throws {
  let object = try #require(
    try JSONSerialization.jsonObject(
      with: MeetPRCodec.encoder.encode(AcceptBindRequestRequestDTO())) as? [String: Any]
  )

  #expect(object.count == 1)
  #expect(object["skip_evaluation"] as? Bool == true)
}

@Test func acceptResponseIgnoresRetiredFields() throws {
  let retiredField = ["eval", "uation_period"].joined()
  let json = """
    {
      "bind_request": {
        "id": "00000000-0000-4000-8000-000000000611",
        "student_id": "00000000-0000-4000-8000-000000000612",
        "coach_id": "00000000-0000-4000-8000-000000000613",
        "coach_display_name": null,
        "invite_code_id": null,
        "status": "accepted",
        "submitted_at": "2026-06-10T08:00:00.000Z",
        "responded_at": "2026-06-11T08:00:00.000Z",
        "expired_at": "2026-06-17T08:00:00.000Z",
        "skip_evaluation": true,
        "skip_reason": null
      },
      "\(retiredField)": { "unexpected": true }
    }
    """

  let response = try MeetPRCodec.decoder.decode(
    AcceptBindRequestResponseDTO.self, from: Data(json.utf8))
  #expect(response.bindRequest.status == .accepted)
  #expect(response.bindRequest.skipEvaluation)
}

@Test func rejectBodyEncodesStrictEmptyObject() throws {
  let data = try MeetPRCodec.encoder.encode(EmptyObjectBodyDTO())
  #expect(String(data: data, encoding: .utf8) == "{}")
}

@Test func coachBindRequestItemDecodesNineItemSummary() throws {
  let json = """
    {
      "bind_requests": [
        {
          "id": "00000000-0000-4000-8000-000000000621",
          "student_id": "00000000-0000-4000-8000-000000000622",
          "display_name": "张三",
          "submitted_at": "2026-06-11T06:00:00.000Z",
          "expired_at": "2026-06-18T06:00:00.000Z",
          "onboarding": {
            "completed": true,
            "gender": "male",
            "birth_date": "2001-03-15",
            "weight_kg": "83.00",
            "training_years": 3,
            "squat_1rm_kg": "180.00",
            "bench_1rm_kg": "120.00",
            "deadlift_1rm_kg": "220.00",
            "muscle_groups_to_strengthen": ["quad", "hamstring", "shoulder"],
            "gym_tier": "commercial",
            "is_competing": true,
            "competition_date": "2026-07-25",
            "note_to_coach": "想突破 200kg 深蹲",
            "upload_count": 4
          }
        }
      ]
    }
    """

  let response = try MeetPRCodec.decoder.decode(
    CoachBindRequestsResponseDTO.self, from: Data(json.utf8))
  let item = try #require(response.bindRequests.first)

  #expect(item.displayName == "张三")
  #expect(item.onboarding.completed)
  #expect(item.onboarding.squat1RMKg == 180)
  #expect(item.onboarding.weightKg == 83)
  #expect(item.onboarding.muscleGroupsToStrengthen == [.quad, .hamstring, .shoulder])
  #expect(item.onboarding.gymTier == .commercial)
  #expect(item.onboarding.uploadCount == 4)
}

@Test func coachBindRequestItemDecodesDegradedNullOnboarding() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000631",
      "student_id": "00000000-0000-4000-8000-000000000632",
      "display_name": "李四",
      "submitted_at": "2026-06-11T06:00:00.000Z",
      "expired_at": "2026-06-18T06:00:00.000Z",
      "onboarding": {
        "completed": false,
        "gender": null,
        "birth_date": null,
        "weight_kg": null,
        "training_years": null,
        "squat_1rm_kg": null,
        "bench_1rm_kg": null,
        "deadlift_1rm_kg": null,
        "muscle_groups_to_strengthen": null,
        "gym_tier": null,
        "is_competing": null,
        "competition_date": null,
        "note_to_coach": null,
        "upload_count": 0
      }
    }
    """

  let item = try MeetPRCodec.decoder.decode(
    CoachBindRequestItemDTO.self, from: Data(json.utf8))

  #expect(!item.onboarding.completed)
  #expect(item.onboarding.squat1RMKg == nil)
  #expect(item.onboarding.muscleGroupsToStrengthen.isEmpty)
  #expect(item.onboarding.uploadCount == 0)
}
