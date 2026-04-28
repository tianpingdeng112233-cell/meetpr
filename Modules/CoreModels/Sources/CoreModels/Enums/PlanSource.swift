import Foundation

public enum PlanSource: String, Codable, Hashable, Sendable, CaseIterable {
  case coach = "coach"  // swiftlint:disable:this redundant_string_enum_value
  case template = "template"  // swiftlint:disable:this redundant_string_enum_value
  case algorithm = "algorithm"  // swiftlint:disable:this redundant_string_enum_value
}
