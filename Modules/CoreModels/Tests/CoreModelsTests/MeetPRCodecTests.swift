import CoreModels
import Foundation
import Testing

@Test func codecEncodesAndDecodesSnakeCaseKeys() throws {
  let probe = CodecKeyProbe(createdAt: createdAt(), displayName: "MeetPR")

  let json = try encodedJSONString(probe)
  let decodedProbe = try MeetPRCodec.decoder.decode(CodecKeyProbe.self, from: Data(json.utf8))

  #expect(json.contains(#""created_at":"#))
  #expect(json.contains(#""display_name":"MeetPR""#))
  #expect(decodedProbe == probe)
}

@Test func codecRoundTripsISO8601Dates() throws {
  let probe = CodecDateProbe(timestamp: createdAt())

  let json = try encodedJSONString(probe)
  let decodedProbe = try MeetPRCodec.decoder.decode(CodecDateProbe.self, from: Data(json.utf8))

  #expect(json.contains(#""timestamp":"2026-04-27T00:00:00Z""#))
  #expect(decodedProbe == probe)
}

private struct CodecKeyProbe: Codable, Equatable, Sendable {
  let createdAt: Date
  let displayName: String
}

private struct CodecDateProbe: Codable, Equatable, Sendable {
  let timestamp: Date
}
