import CoreModels
import Foundation

/// One-line summaries for the nine archive cards (spec 032 §7, wiki line
/// sketches). Age is computed client-side from the date-only birth string
/// (backend D13 — coach side 033 must use the same whole-year calendar
/// difference so both ends agree).
public enum OnboardingSummaryFormatter {
  /// "男 · 25岁 · 178cm · 83kg"
  public static func basics(_ profile: OnboardingProfile, now: Date = Date()) -> String {
    var parts: [String] = []
    if let gender = profile.gender { parts.append(OnboardingLabels.label(gender)) }
    if let age = age(birthDate: profile.birthDate, now: now) { parts.append("\(age)岁") }
    if let height = profile.heightCm {
      parts.append("\(UnitDisplay.plainString(height))cm")
    }
    if let weight = profile.weightKg {
      parts.append("\(UnitDisplay.plainString(weight))kg")
    }
    return joined(parts)
  }

  /// "3年 · 低杠深蹲 · 传统硬拉"
  public static func background(_ profile: OnboardingProfile) -> String {
    var parts: [String] = []
    if let years = profile.trainingYears {
      parts.append(OnboardingLabels.trainingYearsLabel(years))
    }
    if let stance = profile.squatStance {
      parts.append("\(OnboardingLabels.label(stance))深蹲")
    }
    if let style = profile.deadliftStyle {
      parts.append("\(OnboardingLabels.label(style))硬拉")
    }
    return joined(parts)
  }

  /// "S 180 · B 120 · D 220 (kg)"
  public static func oneRM(_ profile: OnboardingProfile) -> String {
    var parts: [String] = []
    if let squat = profile.squat1RMKg { parts.append("S \(UnitDisplay.plainString(squat))") }
    if let bench = profile.bench1RMKg { parts.append("B \(UnitDisplay.plainString(bench))") }
    if let deadlift = profile.deadlift1RMKg {
      parts.append("D \(UnitDisplay.plainString(deadlift))")
    }
    guard !parts.isEmpty else { return placeholder }
    return parts.joined(separator: " · ") + " (kg)"
  }

  /// "周一·三·五·六 (4天/周) · 商业健身房"
  public static func environment(_ profile: OnboardingProfile) -> String {
    var parts: [String] = []
    if !profile.trainingDays.isEmpty {
      let ordered = TrainingDay.allCases.filter { profile.trainingDays.contains($0) }
      var dayText = ordered.map(OnboardingLabels.shortLabel).joined(separator: "·")
      dayText = "周" + dayText
      parts.append("\(dayText) (\(ordered.count)天/周)")
    }
    if let tier = profile.gymTier { parts.append(OnboardingLabels.label(tier)) }
    return joined(parts)
  }

  /// "强度:中等 压力:较高 恢复:正常 睡眠:7h"
  public static func recovery(_ profile: OnboardingProfile) -> String {
    var parts: [String] = []
    if let value = profile.dailyLifeIntensity {
      parts.append(
        "强度:\(OnboardingLabels.scaleLabel(OnboardingLabels.dailyLifeIntensityLabels, notch: value))"
      )
    }
    if let value = profile.lifeStress {
      parts.append(
        "压力:\(OnboardingLabels.scaleLabel(OnboardingLabels.lifeStressLabels, notch: value))")
    }
    if let value = profile.recoverySpeed {
      parts.append(
        "恢复:\(OnboardingLabels.scaleLabel(OnboardingLabels.recoverySpeedLabels, notch: value))"
      )
    }
    if let value = profile.sleepHours {
      parts.append(
        "睡眠:\(OnboardingLabels.scaleLabel(OnboardingLabels.sleepHoursLabels, notch: value))")
    }
    return parts.isEmpty ? placeholder : parts.joined(separator: " ")
  }

  /// "上传 4 份 · 想增强:股四头/腘绳肌/肩" (upload count hidden when 0 —
  /// degraded Step 6).
  public static func materials(_ profile: OnboardingProfile) -> String {
    var parts: [String] = []
    if !profile.uploadAttachmentIds.isEmpty {
      parts.append("上传 \(profile.uploadAttachmentIds.count) 份")
    }
    if !profile.muscleGroupsToStrengthen.isEmpty {
      let names = profile.muscleGroupsToStrengthen.map { group in
        group == .back ? "背" : OnboardingLabels.strengthenLabel(group)
      }
      parts.append("想增强:\(names.joined(separator: "/"))")
    }
    return parts.isEmpty ? "未上传资料" : parts.joined(separator: " · ")
  }

  /// "股四头 / 腘绳肌 / 肩" — just the strengthen targets (no upload count),
  /// for the profile's "想增强肌群" row.
  public static func muscleGroups(_ profile: OnboardingProfile) -> String {
    guard !profile.muscleGroupsToStrengthen.isEmpty else { return placeholder }
    let names = profile.muscleGroupsToStrengthen.map { group in
      group == .back ? "背" : OnboardingLabels.strengthenLabel(group)
    }
    return names.joined(separator: " / ")
  }

  /// "备赛: 2026-07-25 · IPF 83kg" / "暂不备赛"
  public static func competition(_ profile: OnboardingProfile) -> String {
    guard profile.isCompeting == true else {
      return profile.isCompeting == false ? "暂不备赛" : placeholder
    }
    var parts: [String] = []
    if let date = profile.competitionDate { parts.append("备赛: \(date)") }
    if let weightClass = profile.targetWeightClass { parts.append(weightClass) }
    return joined(parts)
  }

  /// "左肩撞击综合征 (肩)" / "无伤病记录"
  public static func injuries(_ profile: OnboardingProfile) -> String {
    let areas = profile.injuryAreas.map(OnboardingLabels.label).joined(separator: "/")
    let notes = profile.injuryNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    switch (notes.isEmpty, areas.isEmpty) {
    case (false, false): return "\(notes) (\(areas))"
    case (false, true): return notes
    case (true, false): return areas
    case (true, true): return "无伤病记录"
    }
  }

  /// Whole-year difference in the local calendar (backend D13 client-side
  /// age policy).
  public static func age(birthDate: String?, now: Date = Date()) -> Int? {
    guard let birth = DateOnly.date(from: birthDate) else { return nil }
    let components = Calendar.current.dateComponents([.year], from: birth, to: now)
    guard let years = components.year, years >= 0 else { return nil }
    return years
  }

  private static let placeholder = "未填写"

  private static func joined(_ parts: [String]) -> String {
    parts.isEmpty ? placeholder : parts.joined(separator: " · ")
  }
}
