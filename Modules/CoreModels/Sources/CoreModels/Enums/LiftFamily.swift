import Foundation

public enum LiftFamily: String, Codable, Hashable, Sendable, CaseIterable {
  case squat = "squat"  // swiftlint:disable:this redundant_string_enum_value
  case bench = "bench"  // swiftlint:disable:this redundant_string_enum_value
  case deadlift = "deadlift"  // swiftlint:disable:this redundant_string_enum_value
}
