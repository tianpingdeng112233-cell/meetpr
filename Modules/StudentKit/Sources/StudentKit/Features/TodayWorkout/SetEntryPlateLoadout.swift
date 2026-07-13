import DesignSystem
import Foundation

extension SetEntrySheet {
  var perSide: Double {
    (NSDecimalNumber(decimal: weightValue).doubleValue - bar) / 2 - collar
  }

  var plates: [Double] {
    perSide > 1e-6 ? PlateLoadout.load(perSide: perSide) : []
  }

  var breakdownLine: String {
    let total = NSDecimalNumber(decimal: weightValue).doubleValue
    guard total >= bar + collar * 2 else { return "空杠 20kg" }
    let base = PlateLoadout.breakdownText(plates)
    return base.isEmpty ? "仅 2.5kg 卡扣" : base + " + 2.5kg 卡扣"
  }
}
