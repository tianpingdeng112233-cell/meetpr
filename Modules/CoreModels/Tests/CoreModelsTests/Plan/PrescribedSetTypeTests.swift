import CoreModels
import Foundation
import Testing

@Test(arguments: ["", ",\"set_type\":null", ",\"set_type\":\"working\""])
func prescribedSetDefaultsToWorkingForLegacyPayloads(typeField: String) throws {
  let payload = """
    {"id":"00000000-0000-0000-0000-000000000001","set_index":0,"reps":5\(typeField)}
    """
  let set = try MeetPRCodec.decoder.decode(PrescribedSet.self, from: Data(payload.utf8))
  #expect(set.setType == .working)
  #expect(set.reps == 5)
}

@Test func prescribedSetDecodesAndRoundTripsFailureType() throws {
  let payload = """
    {"id":"00000000-0000-0000-0000-000000000001","set_index":0,"reps":1,"set_type":"failed"}
    """
  let set = try MeetPRCodec.decoder.decode(PrescribedSet.self, from: Data(payload.utf8))
  #expect(set.setType == .failed)
  #expect(set.reps == 1)
  let data = try MeetPRCodec.encoder.encode(set)
  let json = try #require(String(data: data, encoding: .utf8))
  #expect(json.contains("\"set_type\":\"failed\""))
  #expect(try MeetPRCodec.decoder.decode(PrescribedSet.self, from: data) == set)
}
