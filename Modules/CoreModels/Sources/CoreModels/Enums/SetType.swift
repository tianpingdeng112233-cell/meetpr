import Foundation

public enum SetType: String, Codable, Hashable, Sendable, CaseIterable {
  case warmup = "warmup"  // swiftlint:disable:this redundant_string_enum_value
  case working = "working"  // swiftlint:disable:this redundant_string_enum_value
  case failed = "failed"  // swiftlint:disable:this redundant_string_enum_value
  case amrap = "amrap"  // swiftlint:disable:this redundant_string_enum_value
  case backoff = "backoff"  // swiftlint:disable:this redundant_string_enum_value
}
