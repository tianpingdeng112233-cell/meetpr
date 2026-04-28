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

@Test func codecDecodesDateOnlyStringsAsUTCStartOfDay() throws {
  let json = """
    {
      "start_date": "2026-04-27"
    }
    """

  let decodedProbe = try MeetPRCodec.decoder.decode(CodecDateOnlyProbe.self, from: Data(json.utf8))

  #expect(decodedProbe.startDate == createdAt())
}

@Test func codecStillDecodesFullISO8601Timestamps() throws {
  let json = """
    {
      "start_date": "2026-04-27T00:00:00Z"
    }
    """

  let decodedProbe = try MeetPRCodec.decoder.decode(CodecDateOnlyProbe.self, from: Data(json.utf8))

  #expect(decodedProbe.startDate == createdAt())
}

@Test func codecAcceptsValidLeapYearDate() throws {
  let json = """
    {
      "start_date": "2024-02-29"
    }
    """

  let decodedProbe = try MeetPRCodec.decoder.decode(CodecDateOnlyProbe.self, from: Data(json.utf8))

  // 2024-02-29 00:00:00 UTC = 1_709_164_800
  #expect(decodedProbe.startDate == Date(timeIntervalSince1970: 1_709_164_800))
}

@Test(
  arguments: [
    "2025-02-29",  // not a leap year
    "2026-13-50",  // bad month + day
    "2026-04-31",  // April has 30 days
    "2026-00-15",  // month 0
    "2026-04-00",  // day 0
    "abc-def-ghi",  // not numeric
    "",  // empty
    "2026-04",  // missing day
    "2026-04-27extra",  // trailing junk
  ])
func codecRejectsInvalidDateStrings(rawValue: String) {
  let json = """
    {
      "start_date": "\(rawValue)"
    }
    """

  #expect(throws: (any Error).self) {
    try MeetPRCodec.decoder.decode(CodecDateOnlyProbe.self, from: Data(json.utf8))
  }
}

@Test func userRoundTripsDateOnlyBirthDate() throws {
  // Backend serializes DATE columns as `YYYY-MM-DD` strings (per ADR-004 +
  // backend pg OID 1082 parser). Verify User decodes such payloads end-to-end.
  let json = """
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "phone": "+8613800000000",
      "unit_system": "metric",
      "role": "coached_student",
      "birth_date": "1995-06-15",
      "created_at": "2026-04-27T00:00:00Z",
      "updated_at": "2026-04-27T00:00:00Z"
    }
    """

  let user = try MeetPRCodec.decoder.decode(User.self, from: Data(json.utf8))

  // 1995-06-15 00:00:00 UTC = 803_174_400
  #expect(user.birthDate == Date(timeIntervalSince1970: 803_174_400))
}

private struct CodecKeyProbe: Codable, Equatable, Sendable {
  let createdAt: Date
  let displayName: String
}

private struct CodecDateProbe: Codable, Equatable, Sendable {
  let timestamp: Date
}

private struct CodecDateOnlyProbe: Decodable, Equatable, Sendable {
  let startDate: Date
}
