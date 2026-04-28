import Foundation

public enum IntensityMode: String, Codable, Hashable, Sendable, CaseIterable {
  case weight = "weight"  // swiftlint:disable:this redundant_string_enum_value
  case rpe = "rpe"  // swiftlint:disable:this redundant_string_enum_value
}
