import CoreModels
import Foundation
import Testing

@testable import Networking

// spec 043 §G — coachNote rides the plan-set DTO chain end to end.

@Test func createPlanSetRequestEncodesCoachNoteAsSnakeCase() throws {
  let request = CreatePlanSetRequestDTO(
    setNumber: 1,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: Decimal(string: "100")!,
    setType: .working,
    coachNote: "70%top"
  )

  let json = try #require(String(bytes: MeetPRCodec.encoder.encode(request), encoding: .utf8))

  #expect(json.contains(#""coach_note":"70%top""#))
}

@Test func createPlanSetRequestOmitsCoachNoteWhenNil() throws {
  let request = CreatePlanSetRequestDTO(
    setNumber: 1,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: Decimal(string: "100")!,
    setType: .working
  )

  let json = try #require(String(bytes: MeetPRCodec.encoder.encode(request), encoding: .utf8))

  #expect(!json.contains("coach_note"))
}

@Test func planSetDTODecodesCoachNoteAndPassesItToDomain() throws {
  let json = """
    {
      "id": "90000000-0000-0000-0000-000000000001",
      "plan_exercise_id": "80000000-0000-0000-0000-000000000001",
      "set_number": 1,
      "target_reps": 5,
      "intensity_mode": "weight",
      "target_value": "100",
      "set_type": "working",
      "coach_note": "节奏3-1-0",
      "created_at": "2026-04-25T12:00:00Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(PlanSetDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(dto.coachNote == "节奏3-1-0")
  #expect(domain.coachNote == "节奏3-1-0")
}

@Test func planSetDTODecodesMissingCoachNoteAsNil() throws {
  let json = """
    {
      "id": "90000000-0000-0000-0000-000000000001",
      "plan_exercise_id": "80000000-0000-0000-0000-000000000001",
      "set_number": 1,
      "target_reps": 5,
      "intensity_mode": "weight",
      "target_value": "100",
      "set_type": "working",
      "created_at": "2026-04-25T12:00:00Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(PlanSetDTO.self, from: Data(json.utf8))

  #expect(dto.coachNote == nil)
  #expect(dto.toDomain().coachNote == nil)
}
