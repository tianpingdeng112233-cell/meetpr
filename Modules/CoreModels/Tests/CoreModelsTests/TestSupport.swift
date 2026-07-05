import CoreModels
import Foundation

enum FixtureError: Error {
  case invalidDecimal(String)
  case invalidDate(String)
  case invalidURL(String)
  case invalidUUID(String)
  case invalidUTF8
}

func encodedJSONString<Value: Encodable>(_ value: Value) throws -> String {
  let data = try MeetPRCodec.encoder.encode(value)
  guard let json = String(data: data, encoding: .utf8) else {
    throw FixtureError.invalidUTF8
  }

  return json
}

func fixtureDecimal(_ rawValue: String) throws -> Decimal {
  guard let decimal = Decimal(string: rawValue) else {
    throw FixtureError.invalidDecimal(rawValue)
  }

  return decimal
}

func fixtureURL(_ rawValue: String) throws -> URL {
  guard let url = URL(string: rawValue) else {
    throw FixtureError.invalidURL(rawValue)
  }

  return url
}

func fixtureUUID(_ rawValue: String) throws -> UUID {
  guard let uuid = UUID(uuidString: rawValue) else {
    throw FixtureError.invalidUUID(rawValue)
  }

  return uuid
}

func isoDate(_ rawValue: String) throws -> Date {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime]
  guard let date = formatter.date(from: rawValue) else {
    throw FixtureError.invalidDate(rawValue)
  }

  return date
}

func createdAt() -> Date {
  Date(timeIntervalSince1970: 1_777_248_000)
}

func updatedAt() -> Date {
  Date(timeIntervalSince1970: 1_777_251_600)
}
