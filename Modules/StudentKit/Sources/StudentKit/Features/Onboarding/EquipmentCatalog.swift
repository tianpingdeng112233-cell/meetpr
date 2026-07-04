import CoreModels
import Foundation

/// iOS-owned equipment token vocabulary + per-tier prefill (spec 032 D3 +
/// Step 4 table; the backend stores free TEXT[] — "vocab owned by iOS",
/// zod bounds: ≤30 items / ≤50 chars each).
/// `equipment_overrides` holds the final checked set, never a diff.
///
/// v2 vocabulary (2026-07-02, David sign-off; research + decision record in
/// wiki `domain/gym-tier-equipment-research.md` §6-7). Selection rule: a
/// token exists **iff it changes what the coach can program** — every entry
/// gates ≥1 catalog exercise (海豹划船 2 / 史密斯 24 / 架上销 9 / 倒蹬 9 /
/// 腰带机系 6 / SSB+六角 9 / 地雷+T杆 10 …) or the loading step the coach
/// writes (微增片, 哑铃上限). Comp-environment facts that don't alter
/// programming (校准片 / 镁粉 / combo rack) were cut — they return with the
/// 比赛模式 spec if needed. Prefill is a *prior*; the student's checklist
/// is the truth.
public struct EquipmentItem: Identifiable, Equatable, Sendable {
  /// Step 4 renders one chip grid per group; `dumbbellMax` renders as an
  /// exclusive single-select row (a bucket, not independent switches).
  public enum Group: CaseIterable, Sendable {
    case basics
    case dumbbellMax
    case machines
    case powerlifting
  }

  public let token: String
  public let label: String
  public let group: Group
  public let tiers: Set<GymTier>

  public var id: String { token }
}

public enum EquipmentCatalog {
  private static let everyTier: Set<GymTier> = [.homeWithRack, .commercial, .professional]

  public static let items: [EquipmentItem] = [
    // 基础 — all tiers.
    EquipmentItem(
      token: "barbell_dumbbell", label: "杠铃 + 哑铃", group: .basics, tiers: everyTier),
    EquipmentItem(
      token: "squat_bench_rack", label: "深蹲架 + 卧推架", group: .basics, tiers: everyTier),
    EquipmentItem(
      token: "pullup_bar", label: "引体向上杆", group: .basics, tiers: everyTier),

    // 哑铃最大重量 — exclusive bucket(哑铃动作的可编排上限;中国连锁常见
    // 40kg 封顶,报告 §六 降级链的过滤输入)。
    EquipmentItem(
      token: "db_max_20", label: "哑铃 ≤20kg", group: .dumbbellMax, tiers: [.homeWithRack]),
    EquipmentItem(
      token: "db_max_40", label: "哑铃 ≤40kg", group: .dumbbellMax,
      tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "db_max_40_plus", label: "哑铃 >40kg", group: .dumbbellMax, tiers: []),

    // 固定 / 辅助器械 — each gates catalog exercises the coach may program
    // (Smith rare in PL gyms → not prefilled for .professional).
    EquipmentItem(
      token: "smith_machine", label: "史密斯架", group: .machines, tiers: [.commercial]),
    EquipmentItem(
      token: "cable_crossover", label: "龙门架(大飞鸟)", group: .machines,
      tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "lat_pulldown", label: "高位下拉", group: .machines,
      tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "leg_press_machine", label: "倒蹬机 / 腿举机", group: .machines,
      tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "leg_curl_extension", label: "腿弯举 / 腿屈伸", group: .machines,
      tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "seated_row", label: "坐姿划船", group: .machines,
      tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "landmine", label: "地雷架(含 T 杆划船)", group: .machines,
      tiers: [.commercial, .professional]),
    EquipmentItem(
      token: "seal_row", label: "海豹划船凳", group: .machines, tiers: [.professional]),
    EquipmentItem(
      token: "hack_squat", label: "哈克深蹲机", group: .machines, tiers: [.professional]),

    // 力量举专项 — 变式解锁与加载粒度(教练编排的直接输入)。
    EquipmentItem(
      token: "power_bar_stiff", label: "力量举专项杆(硬杆)", group: .powerlifting,
      tiers: [.professional]),
    EquipmentItem(
      token: "deadlift_bar", label: "硬拉专项杆(软杆)", group: .powerlifting,
      tiers: [.professional]),
    EquipmentItem(
      token: "safety_bar", label: "特种杠(SSB / 六角等)", group: .powerlifting,
      tiers: [.professional]),
    EquipmentItem(
      token: "fractional_plates", label: "微增片(0.25kg 起)", group: .powerlifting,
      tiers: [.professional]),
    EquipmentItem(
      token: "lifting_platform", label: "举重台 / 硬拉台", group: .powerlifting,
      tiers: [.professional]),
    EquipmentItem(
      token: "rack_pins_blocks", label: "架上销 / 垫块", group: .powerlifting,
      tiers: [.professional]),
    EquipmentItem(
      token: "chains_bands", label: "链条 / 弹力带(变阻)", group: .powerlifting,
      tiers: [.professional]),
    EquipmentItem(
      token: "ghr", label: "GHR(臀腿举)", group: .powerlifting, tiers: [.professional]),
    EquipmentItem(
      token: "belt_squat", label: "腰带深蹲机", group: .powerlifting, tiers: [.professional]),
  ]

  /// Retired tokens kept label-resolvable so profiles saved before a
  /// vocabulary change still render: the v1 13-item set, `reverse_hyper`
  /// (dropped 2026-07-02), and `cable_lat_pulldown` (2026-07-02 split into
  /// `cable_crossover` + `lat_pulldown`, relabeled 拉力机 → 龙门架).
  private static let legacyLabels: [String: String] = [
    "heavy_dumbbells": "哑铃区(>30kg)",
    "blocks_chains_bands": "块铃 / 链子 / 弹力带",
    "reverse_hyper": "反向过伸机",
    "cable_lat_pulldown": "拉力机 / 高位下拉",
  ]

  public static func items(in group: EquipmentItem.Group) -> [EquipmentItem] {
    items.filter { $0.group == group }
  }

  /// The mutually exclusive dumbbell-cap bucket (Step 4 enforces single
  /// selection; prefill seeds exactly one per tier).
  public static var dumbbellMaxTokens: [String] {
    items(in: .dumbbellMax).map(\.token)
  }

  /// Checklist prefill when a tier is (re)selected — tier switch resets the
  /// list to this set, discarding manual tweaks after a confirm (D3).
  public static func prefill(for tier: GymTier) -> [String] {
    items.filter { $0.tiers.contains(tier) }.map(\.token)
  }

  public static func label(for token: String) -> String {
    items.first { $0.token == token }?.label ?? legacyLabels[token] ?? token
  }
}
