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
  static func waitingText(since submittedAt: Date, now: Date, locale: Locale = .current) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(submittedAt)))
    if seconds < 3_600 {
      return CoachBindStrings.waitingMinutes(max(1, seconds / 60), locale: locale)
    }
    if seconds < 86_400 {
      let hours = seconds / 3_600
      let minutes = (seconds % 3_600) / 60
      return minutes > 0
        ? CoachBindStrings.waitingHoursMinutes(hours, minutes, locale: locale)
        : CoachBindStrings.waitingHours(hours, locale: locale)
    }
    return CoachBindStrings.waitingDays(seconds / 86_400, locale: locale)
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
  static func trainingYearsText(_ notch: Int, locale: Locale = .current) -> String {
    switch notch {
    case ...0: CoachBindStrings.text("coach.bind.training.lessThanOne", locale: locale)
    case 10...: CoachBindStrings.text("coach.bind.training.tenPlus", locale: locale)
    default: CoachBindStrings.trainingYears(notch, locale: locale)
    }
  }

  // MARK: - Vocabulary labels (wiki student-onboarding v2.4)

  static func genderText(_ gender: Gender, locale: Locale = .current) -> String {
    switch gender {
    case .male: CoachBindStrings.text("coach.bind.gender.male", locale: locale)
    case .female: CoachBindStrings.text("coach.bind.gender.female", locale: locale)
    case .other: CoachBindStrings.text("coach.bind.gender.other", locale: locale)
    }
  }

  static func gymTierText(_ tier: GymTier, locale: Locale = .current) -> String {
    switch tier {
    case .homeWithRack: CoachBindStrings.text("coach.bind.gym.homeWithRack", locale: locale)
    case .commercial: CoachBindStrings.text("coach.bind.gym.commercial", locale: locale)
    case .professional: CoachBindStrings.text("coach.bind.gym.professional", locale: locale)
    }
  }

  static func squatStanceText(_ stance: SquatStance, locale: Locale = .current) -> String {
    switch stance {
    case .highBar: CoachBindStrings.text("coach.bind.squat.highBar", locale: locale)
    case .lowBar: CoachBindStrings.text("coach.bind.squat.lowBar", locale: locale)
    }
  }

  static func deadliftStyleText(_ style: DeadliftStance, locale: Locale = .current) -> String {
    switch style {
    case .conventional: CoachBindStrings.text("coach.bind.deadlift.conventional", locale: locale)
    case .sumo: CoachBindStrings.text("coach.bind.deadlift.sumo", locale: locale)
    case .both: CoachBindStrings.text("coach.bind.deadlift.both", locale: locale)
    }
  }

  static func benchGripText(_ grip: BenchGrip, locale: Locale = .current) -> String {
    switch grip {
    case .narrow: CoachBindStrings.text("coach.bind.bench.narrow", locale: locale)
    case .standard: CoachBindStrings.text("coach.bind.bench.standard", locale: locale)
    case .wide: CoachBindStrings.text("coach.bind.bench.wide", locale: locale)
    }
  }

  static func trainingDayText(_ day: TrainingDay, locale: Locale = .current) -> String {
    switch day {
    case .mon: CoachBindStrings.text("coach.bind.weekday.mon", locale: locale)
    case .tue: CoachBindStrings.text("coach.bind.weekday.tue", locale: locale)
    case .wed: CoachBindStrings.text("coach.bind.weekday.wed", locale: locale)
    case .thu: CoachBindStrings.text("coach.bind.weekday.thu", locale: locale)
    case .fri: CoachBindStrings.text("coach.bind.weekday.fri", locale: locale)
    case .sat: CoachBindStrings.text("coach.bind.weekday.sat", locale: locale)
    case .sun: CoachBindStrings.text("coach.bind.weekday.sun", locale: locale)
    }
  }

  static func injuryAreaText(_ area: InjuryArea, locale: Locale = .current) -> String {
    switch area {
    case .shoulder: CoachBindStrings.text("coach.bind.injury.shoulder", locale: locale)
    case .elbow: CoachBindStrings.text("coach.bind.injury.elbow", locale: locale)
    case .wrist: CoachBindStrings.text("coach.bind.injury.wrist", locale: locale)
    case .lowerBack: CoachBindStrings.text("coach.bind.injury.lowerBack", locale: locale)
    case .hip: CoachBindStrings.text("coach.bind.injury.hip", locale: locale)
    case .knee: CoachBindStrings.text("coach.bind.injury.knee", locale: locale)
    case .ankle: CoachBindStrings.text("coach.bind.injury.ankle", locale: locale)
    case .other: CoachBindStrings.text("coach.bind.injury.other", locale: locale)
    }
  }

  /// Comma-free muscle group list "股四·腘绳·肩" (PlanningDisplay names).
  static func muscleGroupList(_ groups: [MuscleGroup]) -> String {
    PlanningDisplay.deduplicatedMuscleGroupNames(groups).joined(separator: "·")
  }

  // MARK: - Equipment tokens (v2 vocabulary, 2026-07-02)

  /// StudentKit-owned token → coach-facing label. Deliberately a copied
  /// mirror (CoachKit ⊥ StudentKit, ADR-005 §1) of `EquipmentCatalog` plus
  /// the two retired v1 tokens still present in older profiles; unknown
  /// tokens pass through raw so nothing is silently dropped.
  static func equipmentLabel(_ token: String, locale: Locale = .current) -> String {
    guard let key = equipmentLabelKeys[token] else { return token }
    return CoachBindStrings.text(key, locale: locale)
  }

  private static let equipmentLabelKeys: [String: String.LocalizationValue] = [
    "barbell_dumbbell": "coach.bind.equipment.barbellDumbbell",
    "squat_bench_rack": "coach.bind.equipment.squatBenchRack",
    "pullup_bar": "coach.bind.equipment.pullupBar",
    "db_max_20": "coach.bind.equipment.dbMax20",
    "db_max_40": "coach.bind.equipment.dbMax40",
    "db_max_40_plus": "coach.bind.equipment.dbMax40Plus",
    "smith_machine": "coach.bind.equipment.smithMachine",
    "cable_crossover": "coach.bind.equipment.cableCrossover",
    "lat_pulldown": "coach.bind.equipment.latPulldown",
    "leg_press_machine": "coach.bind.equipment.legPress",
    "leg_curl_extension": "coach.bind.equipment.legCurlExtension",
    "seated_row": "coach.bind.equipment.seatedRow",
    "landmine": "coach.bind.equipment.landmine",
    "seal_row": "coach.bind.equipment.sealRow",
    "hack_squat": "coach.bind.equipment.hackSquat",
    "power_bar_stiff": "coach.bind.equipment.powerBar",
    "deadlift_bar": "coach.bind.equipment.deadliftBar",
    "safety_bar": "coach.bind.equipment.safetyBar",
    "fractional_plates": "coach.bind.equipment.fractionalPlates",
    "lifting_platform": "coach.bind.equipment.liftingPlatform",
    "rack_pins_blocks": "coach.bind.equipment.rackPinsBlocks",
    "chains_bands": "coach.bind.equipment.chainsBands",
    "ghr": "coach.bind.equipment.ghr",
    "belt_squat": "coach.bind.equipment.beltSquat",
    // Retired tokens (pre-change profiles): reverse_hyper + v1-set +
    // cable_lat_pulldown (split into cable_crossover + lat_pulldown).
    "reverse_hyper": "coach.bind.equipment.reverseHyper",
    "heavy_dumbbells": "coach.bind.equipment.heavyDumbbells",
    "blocks_chains_bands": "coach.bind.equipment.blocksChainsBands",
    "cable_lat_pulldown": "coach.bind.equipment.cableLatPulldown",
  ]

  // MARK: - Recovery 1-5 scales (wiki v2.1 tables)

  static var dailyLifeIntensityLabels: [String] {
    scaleLabels([
      "coach.bind.scale.daily.1", "coach.bind.scale.daily.2", "coach.bind.scale.daily.3",
      "coach.bind.scale.daily.4", "coach.bind.scale.daily.5",
    ])
  }

  static var lifeStressLabels: [String] {
    scaleLabels([
      "coach.bind.scale.stress.1", "coach.bind.scale.stress.2", "coach.bind.scale.stress.3",
      "coach.bind.scale.stress.4", "coach.bind.scale.stress.5",
    ])
  }

  static var recoverySpeedLabels: [String] {
    scaleLabels([
      "coach.bind.scale.recovery.1", "coach.bind.scale.recovery.2",
      "coach.bind.scale.recovery.3", "coach.bind.scale.recovery.4",
      "coach.bind.scale.recovery.5",
    ])
  }

  static var sleepHoursLabels: [String] {
    scaleLabels([
      "coach.bind.scale.sleep.1", "coach.bind.scale.sleep.2", "coach.bind.scale.sleep.3",
      "coach.bind.scale.sleep.4", "coach.bind.scale.sleep.5",
    ])
  }

  /// "●●●○○" dot strip for a 1-5 notch.
  static func scaleDots(_ notch: Int) -> String {
    let clamped = min(max(notch, 1), 5)
    return String(repeating: "●", count: clamped) + String(repeating: "○", count: 5 - clamped)
  }

  static func scaleLabel(_ labels: [String], notch: Int) -> String {
    let index = min(max(notch - 1, 0), labels.count - 1)
    return labels[index]
  }

  private static func scaleLabels(
    _ keys: [String.LocalizationValue], locale: Locale = .current
  ) -> [String] {
    keys.map { CoachLocalization.localized($0, locale: locale) }
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
