import Foundation

/// Plan kind on the wire (backend spec 005 §endpoint D). Absent on older
/// payloads, so decode sites default to `.regular`.
public enum PlanKind: String, Codable, Hashable, Sendable, CaseIterable {
  case regular = "regular"  // swiftlint:disable:this redundant_string_enum_value
  case adaptation = "adaptation"  // swiftlint:disable:this redundant_string_enum_value
}
