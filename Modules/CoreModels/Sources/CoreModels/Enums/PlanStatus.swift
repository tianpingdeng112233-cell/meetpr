import Foundation

public enum PlanStatus: String, Codable, Hashable, Sendable, CaseIterable {
  case draft = "draft"  // swiftlint:disable:this redundant_string_enum_value
  case published = "published"  // swiftlint:disable:this redundant_string_enum_value
  case completed = "completed"  // swiftlint:disable:this redundant_string_enum_value
  case paused = "paused"  // swiftlint:disable:this redundant_string_enum_value
}
