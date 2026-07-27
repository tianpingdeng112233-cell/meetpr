import CoreModels
import Foundation

/// How planning was entered (spec 033 §7). Non-blank intents preset the
/// student and start at Step 1 — backing out to Step 0 degrades to the
/// blank flow by design.
public enum PlanningIntent: Sendable {
  /// Tab 1 "排新计划": pick a student at Step 0.
  case blank
  /// Adaptation-week entry: kind=adaptation, duration locked to 1
  /// week (UI lock; the publish真 gate is the backend's).
  case adaptationWeek(CoachStudentSummary)
  /// Soft recommendation [立即排]: first regular plan with onboarding
  /// prefill (1RM / training-day badges / equipment filters). The profile is
  /// nil when the fetch missed — planning still opens without prefill.
  case firstRegularPlan(CoachStudentSummary, OnboardingProfile?)
}

extension PlanningIntent {
  var presetStudent: CoachStudentSummary? {
    switch self {
    case .blank: nil
    case .adaptationWeek(let student): student
    case .firstRegularPlan(let student, _): student
    }
  }

  var prefillProfile: OnboardingProfile? {
    switch self {
    case .blank, .adaptationWeek: nil
    case .firstRegularPlan(_, let profile): profile
    }
  }
}

/// Pure prefill mapping (spec 033 §9 table) — kept off the view model so the
/// token → domain rules test in isolation.
enum PlanningPrefill {
  /// Wire training-day tokens → planning day slots (mon=1 … sun=7). Slot
  /// keys stay weekday-shaped on the wire; the UI labels them DAY 1..N by
  /// rank (PlanningViewModel.dayLabel).
  static func preferredDays(from days: [TrainingDay]) -> Set<Int> {
    Set(
      days.map { day in
        switch day {
        case .mon: 1
        case .tue: 2
        case .wed: 3
        case .thu: 4
        case .fri: 5
        case .sat: 6
        case .sun: 7
        }
      })
  }

  /// 1RM trio → per-family conversion bases for Step 4 %1RM mode.
  static func oneRMs(from profile: OnboardingProfile) -> [LiftFamily: Decimal] {
    var result: [LiftFamily: Decimal] = [:]
    result[.squat] = profile.squat1RMKg
    result[.bench] = profile.bench1RMKg
    result[.deadlift] = profile.deadlift1RMKg
    return result
  }

  /// gym_tier + equipment_overrides → initial AccessoryFilters equipment
  /// set. home_with_rack presets the home set; commercial / professional
  /// stay unfiltered (full catalog). Override tokens that hit an Equipment
  /// rawValue merge in; unknown tokens are ignored (the 031 catalog vocab is
  /// intentionally broader). nil = no filter.
  static func equipmentFilter(from profile: OnboardingProfile) -> Set<Equipment>? {
    var equipment: Set<Equipment> = []
    if profile.gymTier == .homeWithRack {
      equipment = [.barbell, .dumbbell, .bodyweight, .band]
    }
    for token in profile.equipmentOverrides {
      if let matched = Equipment(rawValue: token) {
        equipment.insert(matched)
      }
    }
    return equipment.isEmpty ? nil : equipment
  }
}
