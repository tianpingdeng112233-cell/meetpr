import CoreModels
import Foundation

struct MyProfileOneRM: Equatable, Sendable {
  let family: LiftFamily
  let kilograms: Decimal?
}

struct MyProfileV3Presentation: Equatable, Sendable {
  let oneRepMaxima: [MyProfileOneRM]
  let recoveryChips: [String]
  let injuryChips: [String]
  let muscleGroups: String
  let restTimer: String
  let competition: String
  let competitionDate: String?
  let heightAndWeight: String
  let trainingBackground: String
  let trainingEnvironment: String

  var sbdTotalKg: Decimal? {
    let values = oneRepMaxima.compactMap(\.kilograms)
    guard values.count == oneRepMaxima.count else { return nil }
    return values.reduce(0, +)
  }

  static func make(
    profile: OnboardingProfile,
    readiness: ReadinessCheckin?,
    restTimer: StudentRestTimerPreference
  ) -> MyProfileV3Presentation {
    MyProfileV3Presentation(
      oneRepMaxima: [
        MyProfileOneRM(family: .squat, kilograms: profile.squat1RMKg),
        MyProfileOneRM(family: .bench, kilograms: profile.bench1RMKg),
        MyProfileOneRM(family: .deadlift, kilograms: profile.deadlift1RMKg),
      ],
      recoveryChips: recoveryChips(profile: profile, readiness: readiness),
      injuryChips: injuryChips(profile),
      muscleGroups: OnboardingSummaryFormatter.muscleGroups(profile),
      restTimer: restTimerText(restTimer),
      competition: OnboardingSummaryFormatter.competition(profile),
      competitionDate: profile.isCompeting == true ? profile.competitionDate : nil,
      heightAndWeight: heightAndWeight(profile),
      trainingBackground: OnboardingSummaryFormatter.background(profile),
      trainingEnvironment: OnboardingSummaryFormatter.environment(profile)
    )
  }

  private static func recoveryChips(
    profile: OnboardingProfile,
    readiness: ReadinessCheckin?
  ) -> [String] {
    if let readiness {
      return [
        "睡眠 \(readiness.sleepQuality)/5",
        "状态 \(readiness.mood)/5",
        "压力 \(readiness.stress)/5",
      ]
    }
    return [
      profile.dailyLifeIntensity.map {
        OnboardingLabels.scaleLabel(
          OnboardingLabels.dailyLifeIntensityLabels,
          notch: $0
        ) + "强度"
      },
      profile.lifeStress.map {
        OnboardingLabels.scaleLabel(OnboardingLabels.lifeStressLabels, notch: $0) + "压力"
      },
      profile.recoverySpeed.map {
        OnboardingLabels.scaleLabel(OnboardingLabels.recoverySpeedLabels, notch: $0) + "恢复"
      },
    ]
    .compactMap { $0 }
  }

  private static func injuryChips(_ profile: OnboardingProfile) -> [String] {
    guard !profile.injuryAreas.isEmpty else {
      return ["无伤病记录"]
    }
    return profile.injuryAreas.map { area in
      let label = OnboardingLabels.label(area)
      return area == .other ? "其他伤病" : "\(label)部伤病"
    }
  }

  private static func restTimerText(_ preference: StudentRestTimerPreference) -> String {
    guard let seconds = preference.fixedSeconds else { return "自动 (按 RPE)" }
    return "固定 \(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))"
  }

  private static func heightAndWeight(_ profile: OnboardingProfile) -> String {
    var parts: [String] = []
    if let height = profile.heightCm {
      parts.append("\(UnitDisplay.plainString(height)) cm")
    }
    if let weight = profile.weightKg {
      parts.append("\(UnitDisplay.plainString(weight)) kg")
    }
    return parts.isEmpty ? "未填写" : parts.joined(separator: " · ")
  }
}
