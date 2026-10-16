import Foundation
import Testing

@testable import CoreModels

@Test func trainingPlanKindDefaultsToRegularWhenAbsent() throws {
  let json = """
    {
      "id": "00000000-0000-4000-8000-000000000801",
      "coach_id": null,
      "trainee_id": "00000000-0000-4000-8000-000000000802",
      "name": "Legacy plan",
      "start_date": "2026-05-22",
      "end_date": "2026-06-18",
      "plan_weeks": 4,
      "source": "coach",
      "source_template_id": null,
      "status": "published",
      "created_at": "2026-05-22T10:27:16.254Z",
      "updated_at": "2026-05-22T10:27:16.254Z"
    }
    """

  let plan = try MeetPRCodec.decoder.decode(TrainingPlan.self, from: Data(json.utf8))
  #expect(plan.kind == .regular)
}

@Test func trainingPlanKindRoundTripsAdaptation() throws {
  let plan = TrainingPlan(
    id: UUID(),
    traineeID: UUID(),
    name: "适应周",
    startDate: Date(timeIntervalSince1970: 1_780_000_000),
    endDate: Date(timeIntervalSince1970: 1_780_600_000),
    planWeeks: 1,
    kind: .adaptation,
    source: .coach,
    status: .published,
    createdAt: Date(timeIntervalSince1970: 1_780_000_000),
    updatedAt: Date(timeIntervalSince1970: 1_780_000_000)
  )

  let data = try MeetPRCodec.encoder.encode(plan)
  let decoded = try MeetPRCodec.decoder.decode(TrainingPlan.self, from: data)
  #expect(decoded.kind == .adaptation)
}

@Test func studentPlanViewPlanKindDefaultsToRegular() throws {
  let json = """
    {
      "cycle_id": "00000000-0000-4000-8000-000000000901",
      "week_index": 1,
      "start_date": "2026-05-25T00:00:00.000Z",
      "days": []
    }
    """

  let view = try MeetPRCodec.decoder.decode(StudentPlanView.self, from: Data(json.utf8))
  #expect(view.planKind == .regular)
}
