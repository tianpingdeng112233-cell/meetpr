import Foundation

public enum BenchGrip: String, Codable, Hashable, Sendable, CaseIterable {
  case narrow = "narrow"  // swiftlint:disable:this redundant_string_enum_value
  case standard = "standard"  // swiftlint:disable:this redundant_string_enum_value
  case wide = "wide"  // swiftlint:disable:this redundant_string_enum_value
}
