import Foundation

/// Plan kind on the wire (backend spec 005 §endpoint D): `adaptation` is the
/// 1-week evaluation-period plan; everything else is `regular`. Absent on
/// older payloads — decode sites default to `.regular`.
public enum PlanKind: String, Codable, Hashable, Sendable, CaseIterable {
  case regular = "regular"  // swiftlint:disable:this redundant_string_enum_value
  case adaptation = "adaptation"  // swiftlint:disable:this redundant_string_enum_value
}
