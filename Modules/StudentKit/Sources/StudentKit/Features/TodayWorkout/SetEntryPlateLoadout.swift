import DesignSystem
import Foundation

/// Pure plate-calculator math for the set-entry sheet, split out of the view
/// (same pattern as `SetEntryValue`) so the collar (赛扣) arithmetic is
/// unit-testable without constructing the sheet.
@MainActor
enum SetEntryPlateMath {
  static let bar = 20.0
  static let collar = 2.5  // per-side competition collar (赛扣)
  static let defaultCollarOn = false

  static func perSide(total: Double, collarOn: Bool) -> Double {
    (total - bar) / 2 - (collarOn ? collar : 0)
  }

  static func plates(total: Double, collarOn: Bool) -> [Double] {
    plateBreakdown(totalKg: total, hasCollar: collarOn).map(\.weightKg)
  }

  static func breakdownLine(total: Double, collarOn: Bool) -> String {
    let base = PlateVisual.breakdownText(plates(total: total, collarOn: collarOn))
    if collarOn {
      return base.isEmpty ? "仅 2.5kg 赛扣" : base + " + 2.5kg 赛扣"
    }
    return base.isEmpty ? "空杠 20kg" : base
  }
}

extension SetEntrySheet {
  var totalWeight: Double { NSDecimalNumber(decimal: weightValue).doubleValue }

  var perSide: Double { SetEntryPlateMath.perSide(total: totalWeight, collarOn: collarOn) }

  var plates: [Double] { SetEntryPlateMath.plates(total: totalWeight, collarOn: collarOn) }

  var breakdownLine: String {
    SetEntryPlateMath.breakdownLine(total: totalWeight, collarOn: collarOn)
  }
}
