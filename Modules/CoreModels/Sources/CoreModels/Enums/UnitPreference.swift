import Foundation

/// Display-unit preference (spec 032 D1: wire stays metric, lb is a lens).
/// Mirrors backend UNIT_PREFERENCES verbatim (src/db/types.ts).
public enum UnitPreference: String, Codable, Hashable, Sendable, CaseIterable {
  // swiftlint:disable identifier_name redundant_string_enum_value
  case kg = "kg"
  case lb = "lb"
  // swiftlint:enable identifier_name redundant_string_enum_value
}
