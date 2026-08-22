import Foundation

/// A student-facing intensity target independent from any prescribed weight.
public enum PrescribedIntensity: Codable, Hashable, Sendable {
  case percentage(Decimal)
  case rpe(Decimal)
  case rir(Int)
  case rpeRange(Decimal, Decimal)
  case weightRange(Decimal, Decimal)

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let mode = try container.decode(Mode.self, forKey: .mode)
    switch mode {
    case .percentage:
      self = .percentage(try container.decodeDecimal(forKey: .value))
    case .rpe:
      self = .rpe(try container.decodeDecimal(forKey: .value))
    case .rir:
      self = .rir(try container.decode(Int.self, forKey: .value))
    case .rpeRange:
      self = .rpeRange(
        try container.decodeDecimal(forKey: .low),
        try container.decodeDecimal(forKey: .high)
      )
    case .weightRange:
      self = .weightRange(
        try container.decodeDecimal(forKey: .low),
        try container.decodeDecimal(forKey: .high)
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .percentage(let value):
      try container.encode(Mode.percentage, forKey: .mode)
      try container.encodeDecimalString(value, forKey: .value)
    case .rpe(let value):
      try container.encode(Mode.rpe, forKey: .mode)
      try container.encodeDecimalString(value, forKey: .value)
    case .rir(let value):
      try container.encode(Mode.rir, forKey: .mode)
      try container.encode(value, forKey: .value)
    case .rpeRange(let low, let high):
      try container.encode(Mode.rpeRange, forKey: .mode)
      try container.encodeDecimalString(low, forKey: .low)
      try container.encodeDecimalString(high, forKey: .high)
    case .weightRange(let low, let high):
      try container.encode(Mode.weightRange, forKey: .mode)
      try container.encodeDecimalString(low, forKey: .low)
      try container.encodeDecimalString(high, forKey: .high)
    }
  }

  private enum Mode: String, Codable {
    case percentage = "pct"
    case rpe
    case rir
    case rpeRange = "rpe_range"
    case weightRange = "weight_range"
  }

  private enum CodingKeys: String, CodingKey {
    case mode
    case value
    case low
    case high
  }
}
