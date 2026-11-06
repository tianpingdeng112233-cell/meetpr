import CoreModels
import DesignSystem
import Foundation

struct WorkoutKeypadCell: Identifiable, Sendable {
  struct Address: Hashable, Sendable {
    let rowID: UUID
    let field: MeetPRNumberPad.Field
  }
  let rowID: UUID
  let field: MeetPRNumberPad.Field
  let value: String
  var name = ""
  var number = 1
  var unit: String?
  var id: Address { Address(rowID: rowID, field: field) }

  var fieldTitle: String {
    switch field {
    case .weight: StudentStrings.localized(.keypadWeight)
    case .reps: StudentStrings.localized(.setEntrySheet003)
    case .rpe: "RPE"
    case .rir: "RIR"
    }
  }

  var context: String {
    StudentStrings.replacing(.keypadContext, values: [name, String(number), fieldTitle])
  }

  static func cells(
    row: AccessoryRow, name: String, number: Int, includesEffort: Bool
  ) -> [Self] {
    let fields: [MeetPRNumberPad.Field] =
      includesEffort
      ? [.weight, .reps, row.input.effortMode == .rir ? .rir : .rpe] : [.weight, .reps]
    return fields.map { field in
      let value: String
      switch field {
      case .weight: value = row.input.weight
      case .reps: value = row.input.reps
      case .rpe, .rir: value = row.input.rpe
      }
      return Self(
        rowID: row.id, field: field, value: value, name: name, number: number,
        unit: field == .weight ? UnitDisplay.weightUnitSuffix(row.unit).uppercased() : nil)
    }
  }
}

extension AccessoryRow {
  mutating func setKeypadValue(_ value: String, field: MeetPRNumberPad.Field) {
    switch field {
    case .weight: input.weight = value
    case .reps: input.reps = value
    case .rpe, .rir: input.rpe = value
    }
  }
}
