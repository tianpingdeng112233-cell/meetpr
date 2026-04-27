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
    decoder.dateDecodingStrategy = .iso8601
    return decoder
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
