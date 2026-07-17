import DesignSystem
import Foundation

/// Pure plate-calculator math for the set-entry sheet, split out of the view
/// (same pattern as `SetEntryValue`) so the collar (赛扣) arithmetic is
/// unit-testable without constructing the sheet.
@MainActor
enum SetEntryPlateMath {
  static let bar = 20.0
  static let collar = 2.5  // per-side competition collar (赛扣)

  /// UserDefaults key for the 上赛扣 preference, partitioned per student so a
  /// shared device doesn't leak one account's choice into the next login;
  /// nil (demo/previews) falls back to a shared bucket.
  nonisolated static func collarDefaultsKey(for studentID: UUID?) -> String {
    "setEntry.collarOn." + (studentID?.uuidString ?? "shared")
  }

  static func perSide(total: Double, collarOn: Bool) -> Double {
    (total - bar) / 2 - (collarOn ? collar : 0)
  }

  static func plates(total: Double, collarOn: Bool) -> [Double] {
    let side = perSide(total: total, collarOn: collarOn)
    return side > 1e-6 ? PlateLoadout.load(perSide: side) : []
  }

  static func breakdownLine(total: Double, collarOn: Bool) -> String {
    if collarOn {
      guard total >= bar + collar * 2 else { return "空杠 20kg" }
      let base = PlateLoadout.breakdownText(plates(total: total, collarOn: true))
      return base.isEmpty ? "仅 2.5kg 赛扣" : base + " + 2.5kg 赛扣"
    } else {
      guard total > bar + 1e-6 else { return "空杠 20kg" }
      let base = PlateLoadout.breakdownText(plates(total: total, collarOn: false))
      return base.isEmpty ? "空杠 20kg" : base
    }
  }
}

extension SetEntrySheet {
  private var totalWeight: Double { NSDecimalNumber(decimal: weightValue).doubleValue }

  var perSide: Double { SetEntryPlateMath.perSide(total: totalWeight, collarOn: collarOn) }

  var plates: [Double] { SetEntryPlateMath.plates(total: totalWeight, collarOn: collarOn) }

  var breakdownLine: String {
    SetEntryPlateMath.breakdownLine(total: totalWeight, collarOn: collarOn)
  }
}
