import CoreModels
import Foundation

/// Chinese display labels for the onboarding vocabulary (wiki
/// student-onboarding v2.4 copy, verbatim where the wiki specifies). Shared
/// by the wizard steps, the nine-card summaries, and (via 033) the coach's
/// full-profile view.
public enum OnboardingLabels {
  public static func label(_ gender: Gender) -> String {
    switch gender {
    case .male: StudentStrings.localized(.onboardingLabels001)
    case .female: StudentStrings.localized(.onboardingLabels002)
    case .other: StudentStrings.localized(.onboardingLabels003)
    }
  }

  public static func label(_ stance: SquatStance) -> String {
    switch stance {
    case .highBar: StudentStrings.localized(.onboardingLabels004)
    case .lowBar: StudentStrings.localized(.onboardingLabels005)
    }
  }

  public static func label(_ style: DeadliftStance) -> String {
    switch style {
    case .conventional: StudentStrings.localized(.onboardingLabels006)
    case .sumo: StudentStrings.localized(.onboardingLabels007)
    case .both: StudentStrings.localized(.onboardingLabels008)
    }
  }

  public static func label(_ grip: BenchGrip) -> String {
    switch grip {
    case .narrow: StudentStrings.localized(.onboardingLabels009)
    case .standard: StudentStrings.localized(.onboardingLabels010)
    case .wide: StudentStrings.localized(.onboardingLabels011)
    }
  }

  public static func label(_ tier: GymTier) -> String {
    switch tier {
    case .homeWithRack: StudentStrings.localized(.onboardingLabels012)
    case .commercial: StudentStrings.localized(.onboardingLabels013)
    case .professional: StudentStrings.localized(.onboardingLabels014)
    }
  }

  public static func label(_ day: TrainingDay) -> String {
    switch day {
    case .mon: StudentStrings.localized(.onboardingLabels015)
    case .tue: StudentStrings.localized(.onboardingLabels016)
    case .wed: StudentStrings.localized(.onboardingLabels017)
    case .thu: StudentStrings.localized(.onboardingLabels018)
    case .fri: StudentStrings.localized(.onboardingLabels019)
    case .sat: StudentStrings.localized(.onboardingLabels020)
    case .sun: StudentStrings.localized(.onboardingLabels021)
    }
  }

  public static func shortLabel(_ day: TrainingDay) -> String {
    switch day {
    case .mon: StudentStrings.localized(.onboardingLabels022)
    case .tue: StudentStrings.localized(.onboardingLabels023)
    case .wed: StudentStrings.localized(.onboardingLabels024)
    case .thu: StudentStrings.localized(.onboardingLabels025)
    case .fri: StudentStrings.localized(.onboardingLabels026)
    case .sat: StudentStrings.localized(.onboardingLabels027)
    case .sun: StudentStrings.localized(.onboardingLabels028)
    }
  }

  public static func label(_ area: InjuryArea) -> String {
    switch area {
    case .shoulder: StudentStrings.localized(.onboardingLabels029)
    case .elbow: StudentStrings.localized(.onboardingLabels030)
    case .wrist: StudentStrings.localized(.onboardingLabels031)
    case .lowerBack: StudentStrings.localized(.onboardingLabels032)
    case .hip: StudentStrings.localized(.onboardingLabels033)
    case .knee: StudentStrings.localized(.onboardingLabels034)
    case .ankle: StudentStrings.localized(.onboardingLabels035)
    case .other: StudentStrings.localized(.onboardingLabels003)
    }
  }

  /// Step 6 "想增强" chip labels (D4: 背 merges erectors into one token).
  private static let strengthenLabels: [MuscleGroup: String] = [
    .quad: StudentStrings.localized(.onboardingLabels036),
    .hamstring: StudentStrings.localized(.onboardingLabels037),
    .glute: StudentStrings.localized(.onboardingLabels038),
    .back: StudentStrings.localized(.onboardingLabels039),
    .chest: StudentStrings.localized(.onboardingLabels040),
    .shoulder: StudentStrings.localized(.onboardingLabels029),
    .triceps: StudentStrings.localized(.onboardingLabels041),
    .biceps: StudentStrings.localized(.onboardingLabels042),
    .core: StudentStrings.localized(.onboardingLabels043),
    .calf: StudentStrings.localized(.onboardingLabels044),
  ]

  public static func strengthenLabel(_ group: MuscleGroup) -> String {
    strengthenLabels[group] ?? group.rawValue
  }

  /// 0-10 notch labels (D8: 0 = <1 年, 10 = 10+ 年).
  public static func trainingYearsLabel(_ notch: Int) -> String {
    switch notch {
    case ...0: StudentStrings.localized(.onboardingLabels045)
    case 10...: StudentStrings.localized(.onboardingLabels046)
    default: StudentStrings.replacing(.onboardingLabels047, values: ["\(notch)"])
    }
  }

  // MARK: - Step 5 recovery scales (wiki v2.1 tables, 1-5 notches)

  public static let dailyLifeIntensityLabels = [
    StudentStrings.localized(.onboardingLabels048), StudentStrings.localized(.onboardingLabels049),
    StudentStrings.localized(.onboardingLabels050), StudentStrings.localized(.onboardingLabels051),
    StudentStrings.localized(.onboardingLabels052),
  ]
  public static let lifeStressLabels = [
    StudentStrings.localized(.onboardingLabels053), StudentStrings.localized(.onboardingLabels049),
    StudentStrings.localized(.onboardingLabels050), StudentStrings.localized(.onboardingLabels051),
    StudentStrings.localized(.onboardingLabels052),
  ]
  public static let recoverySpeedLabels = [
    StudentStrings.localized(.onboardingLabels054), StudentStrings.localized(.onboardingLabels055),
    StudentStrings.localized(.onboardingLabels056), StudentStrings.localized(.onboardingLabels057),
    StudentStrings.localized(.onboardingLabels058),
  ]
  public static let sleepHoursLabels = ["≤5h", "6h", "7h", "8h", "9h+"]

  /// 1-based notch → label, clamped.
  public static func scaleLabel(_ labels: [String], notch: Int) -> String {
    let index = min(max(notch - 1, 0), labels.count - 1)
    return labels[index]
  }
}
