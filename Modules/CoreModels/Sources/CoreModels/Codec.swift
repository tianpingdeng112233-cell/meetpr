import Foundation

public enum MeetPRCodec {
  public static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  public static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let rawValue = try container.decode(String.self)

      if let timestamp = parseTimestamp(rawValue) {
        return timestamp
      }

      if let dateOnly = parseDateOnly(rawValue) {
        return dateOnly
      }

      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected ISO 8601 timestamp or YYYY-MM-DD date string."
      )
    }
    return decoder
  }

  private static func parseTimestamp(_ rawValue: String) -> Date? {
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    if let timestamp = fractionalFormatter.date(from: rawValue) {
      return timestamp
    }

    let internetDateTimeFormatter = ISO8601DateFormatter()
    internetDateTimeFormatter.formatOptions = [.withInternetDateTime]
    return internetDateTimeFormatter.date(from: rawValue)
  }

  private static func parseDateOnly(_ rawValue: String) -> Date? {
    let parts = rawValue.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3,
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2]),
      let timeZone = TimeZone(secondsFromGMT: 0)
    else {
      return nil
    }

    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = timeZone

    let components = DateComponents(
      calendar: calendar,
      timeZone: timeZone,
      year: year,
      month: month,
      day: day
    )

    guard let date = calendar.date(from: components) else {
      return nil
    }

    let resolved = calendar.dateComponents([.year, .month, .day], from: date)
    guard resolved.year == year,
      resolved.month == month,
      resolved.day == day
    else {
      return nil
    }

    return date
  }
}

extension KeyedDecodingContainer {
  func decodeDecimal(forKey key: Key) throws -> Decimal {
    if let stringValue = try? decode(String.self, forKey: key) {
      guard let decimal = Decimal(string: stringValue) else {
        throw DecodingError.dataCorruptedError(
          forKey: key,
          in: self,
          debugDescription: "Expected Decimal string for \(key.stringValue)"
        )
      }

      return decimal
    }

    return try decode(Decimal.self, forKey: key)
  }

  func decodeDecimalIfPresent(forKey key: Key) throws -> Decimal? {
    guard contains(key), try !decodeNil(forKey: key) else {
      return nil
    }

    if let stringValue = try? decode(String.self, forKey: key) {
      guard let decimal = Decimal(string: stringValue) else {
        throw DecodingError.dataCorruptedError(
          forKey: key,
          in: self,
          debugDescription: "Expected Decimal string for \(key.stringValue)"
        )
      }

      return decimal
    }

    return try decode(Decimal.self, forKey: key)
  }

  func decodeArrayIfPresent<Element: Decodable>(
    _ type: [Element].Type,
    forKey key: Key
  ) throws -> [Element] {
    try decodeIfPresent(type, forKey: key) ?? []
  }
}

extension KeyedEncodingContainer {
  mutating func encodeDecimalString(_ decimal: Decimal, forKey key: Key) throws {
    try encode(NSDecimalNumber(decimal: decimal).stringValue, forKey: key)
  }

  mutating func encodeDecimalStringIfPresent(_ decimal: Decimal?, forKey key: Key) throws {
    guard let decimal else {
      return
    }

    try encodeDecimalString(decimal, forKey: key)
  }
}
