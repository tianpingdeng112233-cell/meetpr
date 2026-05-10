import Foundation

public struct DraftProgressionRule: Codable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public var ruleType: ProgressionRuleType
  public var incrementValue: Decimal?
  public var customSequence: [Decimal]?
  public var customDimension: ProgressionRuleDimension?
  public var exerciseIDs: Set<UUID>
  public var appliedWeeks: Set<Int>
  public var displayOrder: Int

  public init(
    id: UUID = UUID(),
    ruleType: ProgressionRuleType,
    incrementValue: Decimal? = nil,
    customSequence: [Decimal]? = nil,
    customDimension: ProgressionRuleDimension? = nil,
    exerciseIDs: Set<UUID> = [],
    appliedWeeks: Set<Int> = [],
    displayOrder: Int
  ) {
    self.id = id
    self.ruleType = ruleType
    self.incrementValue = incrementValue
    self.customSequence = customSequence
    self.customDimension = customDimension
    self.exerciseIDs = exerciseIDs
    self.appliedWeeks = appliedWeeks
    self.displayOrder = displayOrder
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    ruleType = try container.decode(ProgressionRuleType.self, forKey: .ruleType)
    incrementValue = try container.decodeDecimalStringIfPresent(forKey: .incrementValue)
    customSequence = try container.decodeDecimalStringArrayIfPresent(forKey: .customSequence)
    customDimension = try container.decodeIfPresent(
      ProgressionRuleDimension.self,
      forKey: .customDimension
    )
    exerciseIDs = try container.decode(Set<UUID>.self, forKey: .exerciseIDs)
    appliedWeeks = try container.decode(Set<Int>.self, forKey: .appliedWeeks)
    displayOrder = try container.decode(Int.self, forKey: .displayOrder)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(ruleType, forKey: .ruleType)
    try container.encodeDecimalStringIfPresent(incrementValue, forKey: .incrementValue)
    try container.encodeDecimalStringArrayIfPresent(customSequence, forKey: .customSequence)
    try container.encodeIfPresent(customDimension, forKey: .customDimension)
    try container.encode(exerciseIDs, forKey: .exerciseIDs)
    try container.encode(appliedWeeks, forKey: .appliedWeeks)
    try container.encode(displayOrder, forKey: .displayOrder)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case ruleType
    case incrementValue
    case customSequence
    case customDimension
    case exerciseIDs
    case appliedWeeks
    case displayOrder
  }
}

extension KeyedDecodingContainer {
  func decodeDecimalStringIfPresent(forKey key: Key) throws -> Decimal? {
    guard contains(key), try !decodeNil(forKey: key) else { return nil }
    return try decodeDecimalString(forKey: key)
  }

  func decodeDecimalStringArrayIfPresent(forKey key: Key) throws -> [Decimal]? {
    guard contains(key), try !decodeNil(forKey: key) else { return nil }
    if let strings = try? decode([String].self, forKey: key) {
      return try strings.map { stringValue in
        guard let decimal = Decimal(string: stringValue) else {
          throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected Decimal string array for \(key.stringValue)"
          )
        }
        return decimal
      }
    }
    return try decode([Decimal].self, forKey: key)
  }
}

extension KeyedEncodingContainer {
  mutating func encodeDecimalStringIfPresent(
    _ decimal: Decimal?,
    forKey key: Key
  ) throws {
    guard let decimal else { return }
    try encodeDecimalString(decimal, forKey: key)
  }

  mutating func encodeDecimalStringArrayIfPresent(
    _ decimals: [Decimal]?,
    forKey key: Key
  ) throws {
    guard let decimals else { return }
    let strings = decimals.map { NSDecimalNumber(decimal: $0).stringValue }
    try encode(strings, forKey: key)
  }
}
