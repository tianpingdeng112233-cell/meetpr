import CoreModels
import Foundation
import Testing

@Test func planSetPercentageAnchorRoundTripsAndUnknownValueDecodesAsNil() throws {
  let set = PlanSet(
    id: try #require(UUID(uuidString: "90000000-0000-0000-0000-000000000001")),
    planExerciseID: try #require(UUID(uuidString: "80000000-0000-0000-0000-000000000001")),
    setNumber: 1,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: 0,
    loadMode: .percentage,
    targetPct: 60,
    percentageAnchor: .e1RM,
    setType: .backoff,
    createdAt: Date(timeIntervalSince1970: 1_777_000_000)
  )

  let data = try MeetPRCodec.encoder.encode(set)
  let decodedSet = try MeetPRCodec.decoder.decode(PlanSet.self, from: data)
  let json = try #require(String(bytes: data, encoding: .utf8))
  let futureJSON = json.replacing(#""pct_anchor":"e1rm""#, with: #""pct_anchor":"future""#)
  let futureSet = try MeetPRCodec.decoder.decode(PlanSet.self, from: Data(futureJSON.utf8))

  #expect(decodedSet == set)
  #expect(futureSet.percentageAnchor == nil)
}
