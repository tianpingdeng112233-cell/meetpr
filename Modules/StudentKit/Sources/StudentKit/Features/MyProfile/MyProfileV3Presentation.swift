import CoreModels
import Foundation

struct MyProfileOneRM: Equatable, Sendable {
  let family: LiftFamily
  let kilograms: Decimal?
}

struct MyProfileV3Presentation: Equatable, Sendable {
  let oneRepMaxima: [MyProfileOneRM]
  let injuryChips: [String]
  let restTimer: String
  let competition: String
  let competitionDate: String?
  let heightAndWeight: String
  let trainingBackground: String

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
      injuryChips: injuryChips(profile),
      restTimer: restTimerText(restTimer),
      competition: OnboardingSummaryFormatter.competition(profile),
      competitionDate: profile.isCompeting == true ? profile.competitionDate : nil,
      heightAndWeight: heightAndWeight(profile),
      trainingBackground: OnboardingSummaryFormatter.background(profile)
    )
  }

  private static func injuryChips(_ profile: OnboardingProfile) -> [String] {
    guard !profile.injuryAreas.isEmpty else {
      return [StudentStrings.localized(.myProfileV3Presentation007)]
    }
    return profile.injuryAreas.map { area in
      let label = OnboardingLabels.label(area)
      return area == .other
        ? StudentStrings.localized(.myProfileV3Presentation008)
        : StudentStrings.replacing(.myProfileV3Presentation009, values: ["\(label)"])
    }
  }

  private static func restTimerText(_ preference: StudentRestTimerPreference) -> String {
    StudentRestTimerCopy.summary(for: preference)
  }

  private static func heightAndWeight(_ profile: OnboardingProfile) -> String {
    var parts: [String] = []
    if let height = profile.heightCm {
      parts.append("\(UnitDisplay.plainString(height)) cm")
    }
    if let weight = profile.weightKg {
      parts.append("\(BodyWeightInput.text(kg: weight, unit: .kg)) kg")
    }
    return parts.isEmpty
      ? StudentStrings.localized(.myProfileV3Presentation010) : parts.joined(separator: " · ")
  }
}
