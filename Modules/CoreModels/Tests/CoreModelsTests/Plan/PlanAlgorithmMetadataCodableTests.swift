import CoreModels
import Foundation
import Testing

@Test func trainingPlanDecodesAlgorithmMetadataAndMissingFieldsAsNil() throws {
  let json = """
    {
      "id": "60000000-0000-0000-0000-000000000001",
      "coach_id": "60000000-0000-0000-0000-000000000002",
      "trainee_id": "60000000-0000-0000-0000-000000000003",
      "name": "算法只读周期",
      "start_date": "2026-04-25",
      "end_date": "2026-05-23",
      "plan_weeks": 4,
      "source": "coach",
      "source_template_id": null,
      "status": "published",
      "block_type": "strength",
      "mesocycle_phase": "intensification",
      "training_max": "92.50",
      "tm_set_at": "2026-07-01T12:00:00Z",
      "created_at": "2026-04-25T12:00:00Z",
      "updated_at": "2026-04-25T12:00:00Z"
    }
    """
  let legacyJSON = """
    {
      "id": "60000000-0000-0000-0000-000000000001",
      "coach_id": "60000000-0000-0000-0000-000000000002",
      "trainee_id": "60000000-0000-0000-0000-000000000003",
      "name": "旧计划",
      "start_date": "2026-04-25",
      "end_date": "2026-05-23",
      "plan_weeks": 4,
      "source": "coach",
      "source_template_id": null,
      "status": "published",
      "created_at": "2026-04-25T12:00:00Z",
      "updated_at": "2026-04-25T12:00:00Z"
    }
    """

  let decoded = try MeetPRCodec.decoder.decode(TrainingPlan.self, from: Data(json.utf8))
  let legacy = try MeetPRCodec.decoder.decode(TrainingPlan.self, from: Data(legacyJSON.utf8))
  let expectedTMSetAt = try isoDate("2026-07-01T12:00:00Z")

  #expect(decoded.blockType == "strength")
  #expect(decoded.mesocyclePhase == "intensification")
  #expect(decoded.trainingMax == Decimal(string: "92.50"))
  #expect(decoded.tmSetAt == expectedTMSetAt)
  #expect(legacy.blockType == nil)
  #expect(legacy.mesocyclePhase == nil)
  #expect(legacy.trainingMax == nil)
  #expect(legacy.tmSetAt == nil)
}
