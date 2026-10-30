import CoreModels
import Foundation
import Testing

@testable import Networking

@Test(arguments: ["free_weight", "bodyweight"])
func planLoadTypesDecodeNullLegacyTargets(mode: String) throws {
  let data = Data(
    """
    {"id":"90000000-0000-0000-0000-000000000001",
     "plan_exercise_id":"80000000-0000-0000-0000-000000000001",
     "set_number":1,"target_reps":15,"intensity_mode":null,"target_value":null,
     "load_mode":"\(mode)","target_rpe":"8","set_type":"working",
     "created_at":"2026-04-25T12:00:00Z"}
    """.utf8)
  let dto = try MeetPRCodec.decoder.decode(PlanSetDTO.self, from: data)
  #expect(dto.loadMode?.rawValue == mode)
  #expect(dto.intensityMode == nil)
  #expect(dto.targetValue == nil)
  #expect(dto.toDomain().targetRPE == 8)
  let domain = try MeetPRCodec.decoder.decode(PlanSet.self, from: data)
  #expect(domain == dto.toDomain())
  let restored = try MeetPRCodec.decoder.decode(
    PlanSet.self, from: MeetPRCodec.encoder.encode(domain))
  #expect(restored == domain)
}
