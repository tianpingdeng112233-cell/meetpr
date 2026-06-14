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
    if let squat = profile.squat1RMKg, squat > 0 { parts.append("蹲 \(squat.planningFormatted())") }
    if let bench = profile.bench1RMKg, bench > 0 { parts.append("推 \(bench.planningFormatted())") }
    if let deadlift = profile.deadlift1RMKg, deadlift > 0 {
      parts.append("拉 \(deadlift.planningFormatted())")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " / ")
  }

  static func trainingDays(_ profile: OnboardingProfile) -> String? {
    guard !profile.trainingDays.isEmpty else { return nil }
    let names = profile.trainingDays.map(weekdayLabel).joined(separator: "·")
    return "每周 \(profile.trainingDays.count) 天 (\(names))"
  }

  static func gym(_ profile: OnboardingProfile) -> String? {
    guard let tier = profile.gymTier else { return nil }
    var text = gymTierLabel(tier)
    if !profile.equipmentOverrides.isEmpty {
      text += " · 额外器械 \(profile.equipmentOverrides.count) 项"
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
    return parts.isEmpty ? "有比赛计划" : parts.joined(separator: " · ")
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
    case .male: "男"
    case .female: "女"
    case .other: "其他"
    }
  }

  private static func gymTierLabel(_ tier: GymTier) -> String {
    switch tier {
    case .homeWithRack: "家庭(带架)"
    case .commercial: "商业健身房"
    case .professional: "专业力量举馆"
    }
  }

  private static func weekdayLabel(_ day: TrainingDay) -> String {
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

  private static func injuryAreaLabel(_ area: InjuryArea) -> String {
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
}
