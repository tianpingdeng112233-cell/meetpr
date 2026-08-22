import CoreModels
import Foundation
import Testing

@Test func prescribedSetIndependentWeightAndIntensityRoundTrip() throws {
  let set = PrescribedSet(
    id: UUID(),
    setIndex: 0,
    weightKg: 170,
    intensity: .rpeRange(8, 9),
    reps: 5
  )

  let encoded = try MeetPRCodec.encoder.encode(set)
  let decoded = try MeetPRCodec.decoder.decode(PrescribedSet.self, from: encoded)
  let json = try #require(String(data: encoded, encoding: .utf8))

  #expect(decoded == set)
  #expect(decoded.weightKg == 170)
  #expect(decoded.intensity == .rpeRange(8, 9))
  #expect(decoded.rpe == nil)
  #expect(json.contains(#""intensity":{"high":"9","low":"8","mode":"rpe_range"}"#))
}
