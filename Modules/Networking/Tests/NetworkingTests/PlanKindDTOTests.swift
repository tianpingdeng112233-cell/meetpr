import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func createPlanRequestAlwaysCarriesExplicitKind() throws {
  let regular = CreatePlanRequestDTO(
    traineeID: UUID(),
    name: "正式计划",
    startDate: "2026-06-15",
    endDate: "2026-07-12",
    planWeeks: 4,
    source: .coach
  )
  let regularObject = try #require(
    try JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(regular))
      as? [String: Any])
  #expect(regularObject["kind"] as? String == "regular")

  let adaptation = CreatePlanRequestDTO(
    traineeID: UUID(),
    name: "适应周",
    startDate: "2026-06-15",
    endDate: "2026-06-21",
    planWeeks: 1,
    kind: .adaptation,
    source: .coach
  )
  let adaptationObject = try #require(
    try JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(adaptation))
      as? [String: Any])
  #expect(adaptationObject["kind"] as? String == "adaptation")
}

@Test func planDTODecodesKindWithRegularDefault() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000641",
      "coach_id": null,
      "trainee_id": "00000000-0000-4000-8000-000000000642",
      "name": "适应周",
      "start_date": "2026-06-15",
      "end_date": "2026-06-21",
      "plan_weeks": 1,
      "kind": "adaptation",
      "source": "coach",
      "source_template_id": null,
      "status": "published",
      "created_at": "2026-06-11T08:00:00.000Z",
      "updated_at": "2026-06-11T08:00:00.000Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(PlanDTO.self, from: Data(json.utf8))
  #expect(dto.kind == .adaptation)
  #expect(dto.toDomain().kind == .adaptation)
}
