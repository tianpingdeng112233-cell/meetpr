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
