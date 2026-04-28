import Foundation

public enum MuscleGroup: String, Codable, Hashable, Sendable, CaseIterable {
  case chest = "chest"  // swiftlint:disable:this redundant_string_enum_value
  case shoulder = "shoulder"  // swiftlint:disable:this redundant_string_enum_value
  case back = "back"  // swiftlint:disable:this redundant_string_enum_value
  case biceps = "biceps"  // swiftlint:disable:this redundant_string_enum_value
  case triceps = "triceps"  // swiftlint:disable:this redundant_string_enum_value
  case core = "core"  // swiftlint:disable:this redundant_string_enum_value
  case quad = "quad"  // swiftlint:disable:this redundant_string_enum_value
  case hamstring = "hamstring"  // swiftlint:disable:this redundant_string_enum_value
  case glute = "glute"  // swiftlint:disable:this redundant_string_enum_value
}
