import Foundation

public enum BindRequestStatus: String, Codable, Hashable, Sendable, CaseIterable {
  case pending = "pending"  // swiftlint:disable:this redundant_string_enum_value
  case accepted = "accepted"  // swiftlint:disable:this redundant_string_enum_value
  case rejected = "rejected"  // swiftlint:disable:this redundant_string_enum_value
  case expired = "expired"  // swiftlint:disable:this redundant_string_enum_value
  case cancelled = "cancelled"  // swiftlint:disable:this redundant_string_enum_value
}
