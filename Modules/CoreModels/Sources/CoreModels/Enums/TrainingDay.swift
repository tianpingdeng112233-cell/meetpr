import Foundation

/// Weekday token for onboarding training-day selection (spec 032 Step 4).
/// Mirrors backend TRAINING_DAYS verbatim (src/db/types.ts).
public enum TrainingDay: String, Codable, Hashable, Sendable, CaseIterable {
  case mon = "mon"  // swiftlint:disable:this redundant_string_enum_value
  case tue = "tue"  // swiftlint:disable:this redundant_string_enum_value
  case wed = "wed"  // swiftlint:disable:this redundant_string_enum_value
  case thu = "thu"  // swiftlint:disable:this redundant_string_enum_value
  case fri = "fri"  // swiftlint:disable:this redundant_string_enum_value
  case sat = "sat"  // swiftlint:disable:this redundant_string_enum_value
  case sun = "sun"  // swiftlint:disable:this redundant_string_enum_value
}
