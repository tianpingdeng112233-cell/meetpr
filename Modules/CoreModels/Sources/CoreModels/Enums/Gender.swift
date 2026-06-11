import Foundation

/// Mirrors backend GENDERS verbatim (src/db/types.ts, spec 032 vocab).
public enum Gender: String, Codable, Hashable, Sendable, CaseIterable {
  case male = "male"  // swiftlint:disable:this redundant_string_enum_value
  case female = "female"  // swiftlint:disable:this redundant_string_enum_value
  case other = "other"  // swiftlint:disable:this redundant_string_enum_value
}
