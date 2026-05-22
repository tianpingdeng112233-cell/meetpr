import Foundation

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
}

extension KeyedEncodingContainer {
  mutating func encodeDecimalString(_ decimal: Decimal, forKey key: Key) throws {
    let stringValue: String
    if let scale = wireDecimalScale(for: key.stringValue) {
      stringValue = fixedScaleDecimalString(decimal, scale: scale)
    } else {
      stringValue = NSDecimalNumber(decimal: decimal).stringValue
    }

    try encode(stringValue, forKey: key)
  }

  mutating func encodeDecimalStringIfPresent(_ decimal: Decimal?, forKey key: Key) throws {
    guard let decimal else {
      return
    }

    try encodeDecimalString(decimal, forKey: key)
  }
}

private func wireDecimalScale(for key: String) -> Int? {
  switch key {
  case "target_value", "weight_kg":
    2
  case "rpe":
    1
  default:
    nil
  }
}

private func fixedScaleDecimalString(_ decimal: Decimal, scale: Int) -> String {
  var value = decimal
  var rounded = Decimal()
  NSDecimalRound(&rounded, &value, scale, .plain)

  let rawValue = NSDecimalNumber(decimal: rounded).stringValue
  let parts = rawValue.split(separator: ".", omittingEmptySubsequences: false)
  let whole = String(parts.first ?? "0")
  let fraction = parts.count > 1 ? String(parts[1]) : ""

  guard scale > 0 else {
    return whole
  }

  let paddingCount = max(0, scale - fraction.count)
  let paddedFraction = String(fraction.prefix(scale)) + String(repeating: "0", count: paddingCount)
  return "\(whole).\(paddedFraction)"
}
