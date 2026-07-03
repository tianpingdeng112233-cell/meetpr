import CoreModels
import Foundation

/// CoachKit-internal display mapping for student onboarding data (spec 033
/// §3/§4). Deliberately independent from StudentKit's `OnboardingLabels` —
/// CoachKit ⊥ StudentKit (ADR-005 §1) — with the wiki vocabulary copied
/// verbatim. All time-derived values take an explicit `now` (spec 033
/// §技术要求: wire timestamp + local now, never cached).
enum CoachOnboardingDisplay {
  // MARK: - Client-derived values (backend spec 005 D13)

  /// Calendar age from a "yyyy-MM-dd" birth date; nil when unparseable.
  static func age(birthDate: String?, now: Date, calendar: Calendar = .current) -> Int? {
    guard let birthDate, let birth = parseDateOnly(birthDate, calendar: calendar) else {
      return nil
    }
    let components = calendar.dateComponents([.year], from: birth, to: now)
    guard let years = components.year, years >= 0 else { return nil }
    return years
  }

  /// "已等待 2 小时 14 分" under a day, "已等待 3 天" beyond.
  static func waitingText(since submittedAt: Date, now: Date) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(submittedAt)))
    if seconds < 3_600 {
      return "已等待 \(max(1, seconds / 60)) 分钟"
    }
    if seconds < 86_400 {
      let hours = seconds / 3_600
      let minutes = (seconds % 3_600) / 60
      return minutes > 0 ? "已等待 \(hours) 小时 \(minutes) 分" : "已等待 \(hours) 小时"
    }
    return "已等待 \(seconds / 86_400) 天"
  }

  /// Amber cue when the request lazily expires within 24h (spec 033 §3 #9).
  static func isExpiringSoon(expiredAt: Date, now: Date) -> Bool {
    let remaining = expiredAt.timeIntervalSince(now)
    return remaining > 0 && remaining < 24 * 3_600
  }

  // MARK: - Number formatting

  /// "180.00" → "180", "92.50" → "92.5" (strip trailing zeros for display).
  static func decimalText(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  /// "S:180 B:120 D:220 (kg)"; missing lifts render as "—".
  static func oneRMTrio(squat: Decimal?, bench: Decimal?, deadlift: Decimal?) -> String {
    func part(_ label: String, _ value: Decimal?) -> String {
      "\(label):\(value.map(decimalText) ?? "—")"
    }
    let lifts = [part("S", squat), part("B", bench), part("D", deadlift)]
    return lifts.joined(separator: " ") + " (kg)"
  }

  /// 0 → "训练 <1 年", 10 → "训练 10+ 年", else "训练 N 年".
  static func trainingYearsText(_ notch: Int) -> String {
    switch notch {
    case ...0: "训练 <1 年"
    case 10...: "训练 10+ 年"
    default: "训练 \(notch) 年"
    }
  }

  // MARK: - Vocabulary labels (wiki student-onboarding v2.4)

  static func genderText(_ gender: Gender) -> String {
    switch gender {
    case .male: "男"
    case .female: "女"
    case .other: "其他"
    }
  }

  static func gymTierText(_ tier: GymTier) -> String {
    switch tier {
    case .homeWithRack: "家庭(含深蹲架)"
    case .commercial: "商业健身房"
    case .professional: "专业力量房"
    }
  }

  static func squatStanceText(_ stance: SquatStance) -> String {
    switch stance {
    case .highBar: "高杠"
    case .lowBar: "低杠"
    }
  }

  static func deadliftStyleText(_ style: DeadliftStance) -> String {
    switch style {
    case .conventional: "传统"
    case .sumo: "相扑"
    }
  }

  static func benchGripText(_ grip: BenchGrip) -> String {
    switch grip {
    case .narrow: "窄握"
    case .standard: "标准"
    case .wide: "宽握"
    }
  }

  static func trainingDayText(_ day: TrainingDay) -> String {
    switch day {
    case .mon: "周一"
    case .tue: "周二"
    case .wed: "周三"
    case .thu: "周四"
    case .fri: "周五"
    case .sat: "周六"
    case .sun: "周日"
    }
  }

  static func injuryAreaText(_ area: InjuryArea) -> String {
    switch area {
    case .shoulder: "肩"
    case .elbow: "肘"
    case .wrist: "腕"
    case .lowerBack: "下背"
    case .hip: "髋"
    case .knee: "膝"
    case .ankle: "踝"
    case .other: "其他"
    }
  }

  /// Comma-free muscle group list "股四·腘绳·肩" (PlanningDisplay names).
  static func muscleGroupList(_ groups: [MuscleGroup]) -> String {
    PlanningDisplay.deduplicatedMuscleGroupNames(groups).joined(separator: "·")
  }

  // MARK: - Equipment tokens (v2 vocabulary, 2026-07-02)

  /// StudentKit-owned token → coach-facing label. Deliberately a copied
  /// mirror (CoachKit ⊥ StudentKit, ADR-005 §1) of `EquipmentCatalog` plus
  /// the two retired v1 tokens still present in older profiles; unknown
  /// tokens pass through raw so nothing is silently dropped.
  static func equipmentLabel(_ token: String) -> String {
    equipmentLabels[token] ?? token
  }

  private static let equipmentLabels: [String: String] = [
    "barbell_dumbbell": "杠铃 + 哑铃",
    "squat_bench_rack": "深蹲架 + 卧推架",
    "pullup_bar": "引体向上杆",
    "db_max_20": "哑铃 ≤20kg",
    "db_max_40": "哑铃 ≤40kg",
    "db_max_40_plus": "哑铃 >40kg",
    "smith_machine": "史密斯架",
    "cable_crossover": "龙门架(大飞鸟)",
    "lat_pulldown": "高位下拉",
    "leg_press_machine": "倒蹬机 / 腿举机",
    "leg_curl_extension": "腿弯举 / 腿屈伸",
    "seated_row": "坐姿划船",
    "landmine": "地雷架(含 T 杆划船)",
    "seal_row": "海豹划船凳",
    "hack_squat": "哈克深蹲机",
    "power_bar_stiff": "力量举专项杆(硬杆)",
    "deadlift_bar": "硬拉专项杆(软杆)",
    "safety_bar": "特种杠(SSB / 六角等)",
    "fractional_plates": "微增片(0.25kg 起)",
    "lifting_platform": "举重台 / 硬拉台",
    "rack_pins_blocks": "架上销 / 垫块",
    "chains_bands": "链条 / 弹力带(变阻)",
    "ghr": "GHR(臀腿举)",
    "belt_squat": "腰带深蹲机",
    // Retired tokens (pre-change profiles): reverse_hyper + v1-set +
    // cable_lat_pulldown (split into cable_crossover + lat_pulldown).
    "reverse_hyper": "反向过伸机",
    "heavy_dumbbells": "哑铃区(>30kg)",
    "blocks_chains_bands": "块铃 / 链子 / 弹力带",
    "cable_lat_pulldown": "拉力机 / 高位下拉",
  ]

  // MARK: - Recovery 1-5 scales (wiki v2.1 tables)

  static let dailyLifeIntensityLabels = ["很低", "较低", "中等", "较高", "极高"]
  static let lifeStressLabels = ["几乎无", "较低", "中等", "较高", "极高"]
  static let recoverySpeedLabels = ["3天以上", "约3天", "约2天", "约1天", "半天内"]
  static let sleepHoursLabels = ["≤5h", "6h", "7h", "8h", "9h+"]

  /// "●●●○○" dot strip for a 1-5 notch.
  static func scaleDots(_ notch: Int) -> String {
    let clamped = min(max(notch, 1), 5)
    return String(repeating: "●", count: clamped) + String(repeating: "○", count: 5 - clamped)
  }

  static func scaleLabel(_ labels: [String], notch: Int) -> String {
    let index = min(max(notch - 1, 0), labels.count - 1)
    return labels[index]
  }

  // MARK: - Date helpers

  private static func parseDateOnly(_ rawValue: String, calendar: Calendar) -> Date? {
    let parts = rawValue.split(separator: "-")
    guard parts.count == 3,
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2])
    else { return nil }
    return calendar.date(from: DateComponents(year: year, month: month, day: day))
  }
}
