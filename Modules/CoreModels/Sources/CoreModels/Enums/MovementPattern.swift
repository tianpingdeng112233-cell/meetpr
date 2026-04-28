import Foundation

public enum MovementPattern: String, Codable, Hashable, Sendable, CaseIterable {
  case push = "push"  // swiftlint:disable:this redundant_string_enum_value
  case pull = "pull"  // swiftlint:disable:this redundant_string_enum_value
}
