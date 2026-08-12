import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func planSetDTOsDecodeSixFormsSparseDualAndLegacyRows() throws {
  let sets = try MeetPRCodec.decoder.decode([PlanSetDTO].self, from: Data(planSetsJSON.utf8))

  #expect(sets.count == 10)
  #expect(sets[0].loadMode == .percentage)
  #expect(sets[0].targetPct == 72.5)
  #expect(sets[1].loadMode == .rpe)
  #expect(sets[1].targetRPE == 8.5)
  #expect(sets[2].loadMode == .rir)
  #expect(sets[2].rirTarget == 2)
  #expect(sets[3].loadMode == .weightRange)
  #expect(sets[3].weightLow == 165)
  #expect(sets[3].weightHigh == 175)
  #expect(sets[4].loadMode == .rpeRange)
  #expect(sets[4].rpeLow == 8)
  #expect(sets[4].rpeHigh == 9)
  #expect(sets[5].loadMode == .fixedWeight)
  #expect(sets[5].targetWeight == 170)
  #expect(sets[6].targetWeight == 170)
  #expect(sets[6].targetRPE == 9)
  #expect(sets[7].targetPct == nil)
  #expect(sets[7].targetWeight == 150)
  #expect(sets[8].loadMode == nil)
  #expect(sets[8].intensityMode == .rpe)
  #expect(sets[8].targetValue == 8)
  #expect(sets[9].loadMode == nil)
  #expect(sets[9].intensityMode == .weight)
  #expect(sets[9].targetValue == 140)
}

@Test func planIntensityDTOFieldsRoundTripWithWireTypes() throws {
  let decoded = try MeetPRCodec.decoder.decode([PlanSetDTO].self, from: Data(planSetsJSON.utf8))
  let encoded = try MeetPRCodec.encoder.encode(decoded)
  let json = try #require(String(data: encoded, encoding: .utf8))
  let roundTripped = try MeetPRCodec.decoder.decode([PlanSetDTO].self, from: encoded)

  #expect(roundTripped == decoded)
  #expect(json.contains(#""target_pct":"72.5""#))
  #expect(json.contains(#""rir_target":2"#))
  #expect(json.contains(#""target_weight":"170""#))
}

@Test func planDTOAnchorWeekdayDecodesAndLegacyAbsenceDefaultsNil() throws {
  let anchored = try MeetPRCodec.decoder.decode(
    PlanDTO.self,
    from: Data(planJSON(anchorLine: #""anchor_weekday": 3,"#).utf8)
  )
  let legacy = try MeetPRCodec.decoder.decode(
    PlanDTO.self,
    from: Data(planJSON(anchorLine: "").utf8)
  )

  #expect(anchored.anchorWeekday == 3)
  #expect(legacy.anchorWeekday == nil)
  #expect(anchored.toDomain().anchorWeekday == 3)
}

private func planJSON(anchorLine: String) -> String {
  """
  {
    "id": "10000000-0000-0000-0000-000000000001",
    "coach_id": "10000000-0000-0000-0000-000000000002",
    "trainee_id": "10000000-0000-0000-0000-000000000003",
    "name": "强度计划",
    "start_date": "2026-08-12",
    "end_date": "2026-09-08",
    "plan_weeks": 4,
    \(anchorLine)
    "source": "coach",
    "status": "published",
    "created_at": "2026-08-12T08:00:00Z",
    "updated_at": "2026-08-12T08:00:00Z"
  }
  """
}

// One compact object per heterogeneous set keeps the wire fixture auditable.
// swiftlint:disable line_length
private let planSetsJSON = """
  [
    {"id":"20000000-0000-0000-0000-000000000001","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":1,"target_reps":5,"intensity_mode":"rpe","target_value":"7.1","load_mode":"pct","target_pct":"72.5","set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000002","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":2,"target_reps":5,"intensity_mode":"rpe","target_value":"8.5","load_mode":"rpe","target_rpe":"8.5","set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000003","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":3,"target_reps":5,"intensity_mode":"rpe","target_value":"8","load_mode":"rir","rir_target":2,"set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000004","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":4,"target_reps":5,"intensity_mode":"weight","target_value":"165","load_mode":"weight_range","weight_low":"165.00","weight_high":"175.00","set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000005","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":5,"target_reps":5,"intensity_mode":"rpe","target_value":"8","load_mode":"rpe_range","rpe_low":"8.0","rpe_high":"9.0","set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000006","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":6,"target_reps":5,"intensity_mode":"weight","target_value":"170","load_mode":"fixed_weight","target_weight":"170.00","set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000007","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":7,"target_reps":5,"intensity_mode":"weight","target_value":"170","load_mode":"rpe","target_rpe":"9.0","target_weight":"170.00","set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000008","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":8,"target_reps":5,"intensity_mode":"weight","target_value":"150","load_mode":"pct","target_pct":null,"target_weight":"150.00","set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000009","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":9,"target_reps":5,"intensity_mode":"rpe","target_value":"8","set_type":"working","created_at":"2026-08-12T08:00:00Z"},
    {"id":"20000000-0000-0000-0000-000000000010","plan_exercise_id":"30000000-0000-0000-0000-000000000001","set_number":10,"target_reps":5,"intensity_mode":"weight","target_value":"140","set_type":"working","created_at":"2026-08-12T08:00:00Z"}
  ]
  """
// swiftlint:enable line_length
