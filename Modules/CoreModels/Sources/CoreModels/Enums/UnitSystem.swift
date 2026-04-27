import Foundation

public enum UnitSystem: String, Codable, Hashable, Sendable, CaseIterable {
  case metric = "metric"  // swiftlint:disable:this redundant_string_enum_value
  case imperial = "imperial"  // swiftlint:disable:this redundant_string_enum_value
}
