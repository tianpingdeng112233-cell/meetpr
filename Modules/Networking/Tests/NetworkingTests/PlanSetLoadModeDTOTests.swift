import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func planSetDTODecodesMissingLoadModeAsNil() throws {
  let dto = try decodePlanSet(loadMode: nil)

  #expect(dto.loadMode == nil)
  #expect(dto.toDomain().loadMode == nil)
}

@Test func planSetDTODecodesPctLoadModeAndPassesItToDomain() throws {
  let dto = try decodePlanSet(loadMode: "pct")

  #expect(dto.loadMode == "pct")
  #expect(dto.toDomain().loadMode == "pct")
}

@Test func planSetDTODecodesUnknownLoadModeWithoutRejectingTheResponse() throws {
  let dto = try decodePlanSet(loadMode: "future_mode")

  #expect(dto.loadMode == "future_mode")
  #expect(dto.toDomain().loadMode == "future_mode")
}

private func decodePlanSet(loadMode: String?) throws -> PlanSetDTO {
  let loadModeField = loadMode.map { ",\n  \"load_mode\": \"\($0)\"" } ?? ""
  let json = """
    {
      "id": "90000000-0000-0000-0000-000000000001",
      "plan_exercise_id": "80000000-0000-0000-0000-000000000001",
      "set_number": 1,
      "target_reps": 5,
      "intensity_mode": "rpe",
      "target_value": "6",
      "set_type": "working"\(loadModeField),
      "created_at": "2026-04-25T12:00:00Z"
    }
    """
  return try MeetPRCodec.decoder.decode(PlanSetDTO.self, from: Data(json.utf8))
}
