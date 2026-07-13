import DesignSystem
import Foundation

extension SetEntrySheet {
  var perSide: Double {
    (NSDecimalNumber(decimal: weightValue).doubleValue - bar) / 2 - (collarOn ? collar : 0)
  }

  var plates: [Double] {
    perSide > 1e-6 ? PlateLoadout.load(perSide: perSide) : []
  }

  var breakdownLine: String {
    let total = NSDecimalNumber(decimal: weightValue).doubleValue
    if collarOn {
      guard total >= bar + collar * 2 else { return "空杠 20kg" }
      let base = PlateLoadout.breakdownText(plates)
      return base.isEmpty ? "仅 2.5kg 赛扣" : base + " + 2.5kg 赛扣"
    } else {
      guard total > bar + 1e-6 else { return "空杠 20kg" }
      let base = PlateLoadout.breakdownText(plates)
      return base.isEmpty ? "空杠 20kg" : base
    }
  }
}
