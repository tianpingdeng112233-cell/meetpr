import Foundation

public enum Equipment: String, Codable, Hashable, Sendable, CaseIterable {
  case barbell = "barbell"  // swiftlint:disable:this redundant_string_enum_value
  case dumbbell = "dumbbell"  // swiftlint:disable:this redundant_string_enum_value
  case machine = "machine"  // swiftlint:disable:this redundant_string_enum_value
  case bodyweight = "bodyweight"  // swiftlint:disable:this redundant_string_enum_value
}
