import CoreModels
import Foundation

/// iOS-owned equipment token vocabulary + per-tier prefill (spec 032 D3 +
/// Step 4 table; the backend stores free TEXT[] — "vocab owned by iOS").
/// `equipment_overrides` holds the final checked set, never a diff.
/// Changing this list = spec revision (Class 1; wiki notes 肖+里欧 review
/// pending on the catalog).
public struct EquipmentItem: Identifiable, Equatable, Sendable {
  public let token: String
  public let label: String
  public let tiers: Set<GymTier>

  public var id: String { token }
}

public enum EquipmentCatalog {
  public static let items: [EquipmentItem] = [
    EquipmentItem(
      token: "barbell_dumbbell", label: "杠铃 + 哑铃",
      tiers: [.homeWithRack, .commercial, .professional]),
    EquipmentItem(
      token: "squat_bench_rack", label: "深蹲架 + 卧推架",
      tiers: [.homeWithRack, .commercial, .professional]),
    EquipmentItem(
      token: "pullup_bar", label: "引体向上杆",
      tiers: [.homeWithRack, .commercial, .professional]),
    EquipmentItem(
      token: "cable_lat_pulldown", label: "拉力机 / 高位下拉",
      tiers: [.commercial, .professional]),
    EquipmentItem(token: "smith_machine", label: "史密斯架", tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "heavy_dumbbells", label: "哑铃区(>30kg)", tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "leg_press_machine", label: "蹲举机", tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "leg_curl_extension", label: "腿弯机 / 腿伸机", tiers: [.commercial, .professional]),
    EquipmentItem(token: "seated_row", label: "坐姿划船", tiers: [.commercial, .professional]),
    EquipmentItem(token: "lifting_platform", label: "举重台", tiers: [.professional]),
    EquipmentItem(
      token: "blocks_chains_bands", label: "块铃 / 链子 / 弹力带", tiers: [.professional]),
    EquipmentItem(token: "hack_squat", label: "哈克深蹲架", tiers: [.professional]),
    EquipmentItem(token: "safety_bar", label: "安全杠", tiers: [.professional]),
  ]

  /// Checklist prefill when a tier is (re)selected — tier switch resets the
  /// list to this set, discarding manual tweaks after a confirm (D3).
  public static func prefill(for tier: GymTier) -> [String] {
    items.filter { $0.tiers.contains(tier) }.map(\.token)
  }

  public static func label(for token: String) -> String {
    items.first { $0.token == token }?.label ?? token
  }
}
