import CoreModels
import Foundation

/// Chinese display labels for the onboarding vocabulary (wiki
/// student-onboarding v2.4 copy, verbatim where the wiki specifies). Shared
/// by the wizard steps, the nine-card summaries, and (via 033) the coach's
/// full-profile view.
public enum OnboardingLabels {
  public static func label(_ gender: Gender) -> String {
    switch gender {
    case .male: "男"
    case .female: "女"
    case .other: "其他"
    }
  }

  public static func label(_ stance: SquatStance) -> String {
    switch stance {
    case .highBar: "高杠"
    case .lowBar: "低杠"
    }
  }

  public static func label(_ style: DeadliftStance) -> String {
    switch style {
    case .conventional: "传统"
    case .sumo: "相扑"
    case .both: "两种都练"
    }
  }

  public static func label(_ grip: BenchGrip) -> String {
    switch grip {
    case .narrow: "窄握"
    case .standard: "标准"
    case .wide: "宽握"
    }
  }

  public static func label(_ tier: GymTier) -> String {
    switch tier {
    case .homeWithRack: "家庭(含深蹲架)"
    case .commercial: "商业健身房"
    case .professional: "专业力量馆"
    }
  }

  public static func label(_ day: TrainingDay) -> String {
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

  public static func shortLabel(_ day: TrainingDay) -> String {
    switch day {
    case .mon: "一"
    case .tue: "二"
    case .wed: "三"
    case .thu: "四"
    case .fri: "五"
    case .sat: "六"
    case .sun: "日"
    }
  }

  public static func label(_ area: InjuryArea) -> String {
    switch area {
    case .shoulder: "肩"
    case .elbow: "肘"
    case .wrist: "腕"
    case .lowerBack: "腰"
    case .hip: "髋"
    case .knee: "膝"
    case .ankle: "踝"
    case .other: "其他"
    }
  }

  /// Step 6 "想增强" chip labels (D4: 背 merges erectors into one token).
  private static let strengthenLabels: [MuscleGroup: String] = [
    .quad: "股四头",
    .hamstring: "腘绳肌",
    .glute: "臀",
    .back: "背(含竖脊肌)",
    .chest: "胸",
    .shoulder: "肩",
    .triceps: "肱三头",
    .biceps: "肱二头",
    .core: "核心",
    .calf: "小腿",
  ]

  public static func strengthenLabel(_ group: MuscleGroup) -> String {
    strengthenLabels[group] ?? group.rawValue
  }

  /// 0-10 notch labels (D8: 0 = <1 年, 10 = 10+ 年).
  public static func trainingYearsLabel(_ notch: Int) -> String {
    switch notch {
    case ...0: "<1 年"
    case 10...: "10+ 年"
    default: "\(notch) 年"
    }
  }

  // MARK: - Step 5 recovery scales (wiki v2.1 tables, 1-5 notches)

  public static let dailyLifeIntensityLabels = ["很低", "较低", "中等", "较高", "极高"]
  public static let lifeStressLabels = ["几乎无", "较低", "中等", "较高", "极高"]
  public static let recoverySpeedLabels = ["3天以上", "约3天", "约2天", "约1天", "半天内"]
  public static let sleepHoursLabels = ["≤5h", "6h", "7h", "8h", "9h+"]

  /// 1-based notch → label, clamped.
  public static func scaleLabel(_ labels: [String], notch: Int) -> String {
    let index = min(max(notch - 1, 0), labels.count - 1)
    return labels[index]
  }
}
