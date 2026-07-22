import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func readinessEnergyEncodesAndDecodesAcrossWireDTOs() throws {
  let request = SubmitReadinessRequestDTO(
    checkinDate: "2026-07-22",
    sleepQuality: 4,
    energy: 5,
    mood: 3,
    stress: 2,
    muscleFatigue: [MuscleFatigueDTO(muscleGroup: "quad", severity: 4)]
  )
  let requestObject = try #require(
    JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(request)) as? [String: Any]
  )

  #expect(requestObject["energy"] as? Int == 5)
  #expect(requestObject["muscle_fatigue"] != nil)

  let responseJSON = """
    {
      "id": "00000000-0000-4000-8000-000000000401",
      "student_id": "00000000-0000-4000-8000-000000000402",
      "checkin_date": "2026-07-22",
      "sleep_quality": 4,
      "energy": 5,
      "mood": 3,
      "stress": 2,
      "muscle_fatigue": [{"muscle_group": "quad", "severity": 4}],
      "submitted_at": "2026-07-22T08:00:00Z"
    }
    """
  let decoded = try MeetPRCodec.decoder.decode(
    ReadinessCheckinDTO.self,
    from: Data(responseJSON.utf8)
  )
  let redecoded = try MeetPRCodec.decoder.decode(
    ReadinessCheckinDTO.self,
    from: MeetPRCodec.encoder.encode(decoded)
  )

  #expect(decoded.energy == 5)
  #expect(decoded.toDomain()?.energy == 5)
  #expect(redecoded == decoded)
}

@Test func readinessResponseWithoutEnergyRemainsBackwardCompatible() throws {
  let responseJSON = """
    {
      "id": "00000000-0000-4000-8000-000000000401",
      "student_id": "00000000-0000-4000-8000-000000000402",
      "checkin_date": "2026-07-21",
      "sleep_quality": 4,
      "mood": 3,
      "stress": 2,
      "muscle_fatigue": [],
      "submitted_at": "2026-07-21T08:00:00Z"
    }
    """
  let decoded = try MeetPRCodec.decoder.decode(
    ReadinessCheckinDTO.self,
    from: Data(responseJSON.utf8)
  )

  #expect(decoded.energy == nil)
  #expect(decoded.toDomain()?.energy == nil)
}

@Test func readinessRequestOmitsTheEnergyKeyWhenUnset() throws {
  let request = SubmitReadinessRequestDTO(
    checkinDate: "2026-07-22",
    sleepQuality: 4,
    mood: 3,
    stress: 2,
    muscleFatigue: []
  )
  let requestObject = try #require(
    JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(request)) as? [String: Any]
  )

  // 后端 ReadinessBodySchema 的 energy 是 z.number().optional() —— 接受「键缺席」,
  // 但 null 会被判类型不符而 400。合成的 Codable 对 Optional 用 encodeIfPresent,
  // 所以键会整个缺席;这条断言把它锁住,防止有人日后给 DTO 加自定义 encode 时
  // 改成 encode(_:forKey:),让所有没填精力的 check-in 提交静默失败。
  #expect(!requestObject.keys.contains("energy"))
}
