import CoreModels
import Foundation

/// Pure formatters for the planning student header's expanded detail
/// (David 2026-06-14). Kept off the view so the field selection / fallbacks
/// test in isolation. Every getter returns nil when there's nothing useful
/// to show, so the header only renders rows that carry information.
enum StudentProfileSummary {
  static func basics(_ profile: OnboardingProfile) -> String? {
    var parts: [String] = []
    if let gender = profile.gender { parts.append(genderLabel(gender)) }
    if let weight = profile.weightKg, weight > 0 {
      parts.append("\(weight.planningFormatted())kg")
    }
    if let height = profile.heightCm, height > 0 {
      parts.append("\(height.planningFormatted())cm")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  static func oneRMs(_ profile: OnboardingProfile) -> String? {
    var parts: [String] = []
    if let squat = profile.squat1RMKg, squat > 0 {
      parts.append(CoachPlanningStrings.oneRMSquat(squat.planningFormatted()))
    }
    if let bench = profile.bench1RMKg, bench > 0 {
      parts.append(CoachPlanningStrings.oneRMBench(bench.planningFormatted()))
    }
    if let deadlift = profile.deadlift1RMKg, deadlift > 0 {
      parts.append(CoachPlanningStrings.oneRMDeadlift(deadlift.planningFormatted()))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " / ")
  }

  static func trainingDays(_ profile: OnboardingProfile) -> String? {
    guard !profile.trainingDays.isEmpty else { return nil }
    let names = profile.trainingDays.map(weekdayLabel).joined(separator: "·")
    return CoachPlanningStrings.weeklyTrainingDays(
      count: profile.trainingDays.count,
      names: names
    )
  }

  static func gym(_ profile: OnboardingProfile) -> String? {
    guard let tier = profile.gymTier else { return nil }
    var text = gymTierLabel(tier)
    if !profile.equipmentOverrides.isEmpty {
      text += " · " + CoachPlanningStrings.extraEquipment(profile.equipmentOverrides.count)
    }
    return text
  }

  static func injuries(_ profile: OnboardingProfile) -> String? {
    var parts: [String] = []
    if !profile.injuryAreas.isEmpty {
      parts.append(profile.injuryAreas.map(injuryAreaLabel).joined(separator: "·"))
    }
    if let notes = trimmed(profile.injuryNotes) { parts.append(notes) }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  static func competition(_ profile: OnboardingProfile) -> String? {
    guard profile.isCompeting == true else { return nil }
    var parts: [String] = []
    if let date = trimmed(profile.competitionDate) { parts.append(date) }
    if let weightClass = trimmed(profile.targetWeightClass) { parts.append(weightClass) }
    return parts.isEmpty ? CoachPlanningStrings.competitionPlanned : parts.joined(separator: " · ")
  }

  static func noteToCoach(_ profile: OnboardingProfile) -> String? {
    trimmed(profile.noteToCoach)
  }

  // MARK: - Labels

  private static func trimmed(_ value: String?) -> String? {
    guard let value else { return nil }
    let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? nil : cleaned
  }

  private static func genderLabel(_ gender: Gender) -> String {
    switch gender {
    case .male: CoachPlanningStrings.male
    case .female: CoachPlanningStrings.female
    case .other: CoachPlanningStrings.other
    }
  }

  private static func gymTierLabel(_ tier: GymTier) -> String {
    switch tier {
    case .homeWithRack: CoachPlanningStrings.homeGymWithRack
    case .commercial: CoachPlanningStrings.commercialGym
    case .professional: CoachPlanningStrings.powerliftingGym
    }
  }

  private static func weekdayLabel(_ day: TrainingDay) -> String {
    switch day {
    case .mon: CoachPlanningStrings.mondayShort
    case .tue: CoachPlanningStrings.tuesdayShort
    case .wed: CoachPlanningStrings.wednesdayShort
    case .thu: CoachPlanningStrings.thursdayShort
    case .fri: CoachPlanningStrings.fridayShort
    case .sat: CoachPlanningStrings.saturdayShort
    case .sun: CoachPlanningStrings.sundayShort
    }
  }

  private static func injuryAreaLabel(_ area: InjuryArea) -> String {
    switch area {
    case .shoulder: CoachPlanningStrings.shoulderInjury
    case .elbow: CoachPlanningStrings.elbowInjury
    case .wrist: CoachPlanningStrings.wristInjury
    case .lowerBack: CoachPlanningStrings.lowerBackInjury
    case .hip: CoachPlanningStrings.hipInjury
    case .knee: CoachPlanningStrings.kneeInjury
    case .ankle: CoachPlanningStrings.ankleInjury
    case .other: CoachPlanningStrings.other
    }
  }
}
