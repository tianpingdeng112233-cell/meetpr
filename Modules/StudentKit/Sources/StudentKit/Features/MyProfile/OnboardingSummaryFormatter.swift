import CoreModels
import Foundation

/// One-line summaries for the retained archive cards (spec 032 §7, wiki line
/// sketches). Age is computed client-side from the date-only birth string
/// (backend D13 — coach side 033 must use the same whole-year calendar
/// difference so both ends agree).
public enum OnboardingSummaryFormatter {
  /// "男 · 25岁 · 178cm · 83kg"
  public static func basics(_ profile: OnboardingProfile, now: Date = Date()) -> String {
    var parts: [String] = []
    if let gender = profile.gender { parts.append(OnboardingLabels.label(gender)) }
    if let age = age(birthDate: profile.birthDate, now: now) {
      parts.append(StudentStrings.replacing(.onboardingSummaryFormatter001, values: ["\(age)"]))
    }
    if let height = profile.heightCm {
      parts.append("\(UnitDisplay.plainString(height))cm")
    }
    if let weight = profile.weightKg {
      parts.append("\(BodyWeightInput.text(kg: weight, unit: .kg))kg")
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
      parts.append(
        StudentStrings.replacing(
          .onboardingSummaryFormatter002, values: ["\(OnboardingLabels.label(stance))"]))
    }
    if let style = profile.deadliftStyle {
      parts.append(
        StudentStrings.replacing(
          .onboardingSummaryFormatter003, values: ["\(OnboardingLabels.label(style))"]))
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

  /// "备赛: 2026-07-25 · IPF 83kg" / "暂不备赛"
  public static func competition(_ profile: OnboardingProfile) -> String {
    guard profile.isCompeting == true, let date = profile.competitionDate else {
      return placeholder
    }
    var parts = [date]
    if let weightClass = profile.targetWeightClass, !weightClass.isEmpty {
      parts.append(weightClass)
    }
    return joined(parts)
  }

  public static func note(_ profile: OnboardingProfile) -> String {
    guard let note = profile.noteToCoach, !note.isEmpty else { return placeholder }
    let firstLine = note.components(separatedBy: .newlines).first ?? ""
    return firstLine.isEmpty ? placeholder : firstLine
  }

  /// "左肩撞击综合征 (肩)" / "无伤病记录"
  public static func injuries(_ profile: OnboardingProfile) -> String {
    let areas = profile.injuryAreas.map(OnboardingLabels.label).joined(separator: "/")
    let notes = profile.injuryNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    switch (notes.isEmpty, areas.isEmpty) {
    case (false, false): return "\(notes) (\(areas))"
    case (false, true): return notes
    case (true, false): return areas
    case (true, true): return StudentStrings.localized(.onboardingSummaryFormatter016)
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

  private static let placeholder = StudentStrings.localized(.onboardingSummaryFormatter017)

  private static func joined(_ parts: [String]) -> String {
    parts.isEmpty ? placeholder : parts.joined(separator: " · ")
  }
}
