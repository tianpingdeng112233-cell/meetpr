import CoreModels
import Foundation

/// A display-only projection. Drafts carry the prescription, recorded values and prefill;
/// summarizing them never writes records or accepts a suggestion on the student's behalf.
struct AllDayExerciseSummary: Equatable, Sendable {
  struct Segment: Equatable, Sendable {
    var reps: String
    var load: String
    var intensityOnly = false
    var repsChanged = false
    var loadChanged = false
    var shortReps = false
  }
  let segments: [Segment]

  static func build(
    rows: [TodayWorkoutSetRowDraft], unit: UnitPreference = .kg,
    locale: Locale = .current
  ) -> Self {
    let efforts = rows.map { row -> String? in
      if row.hasSavedRecord || row.completed || row.isStudentAdded {
        if let rir = row.actualRIR { return "RIR \(rir)" }
        return row.actualRPE.map { "RPE " + StudentFormatting.decimal($0) }
      }
      return effort(row.prescribed)
    }
    let commonEffort = efforts.first.flatMap { first in
      efforts.allSatisfy { $0 == first } ? first : nil
    }
    let values = rows.map { segment($0, commonEffort: commonEffort, unit: unit, locale: locale) }
    var groups: [[Segment]] = []
    for value in values {
      if let last = groups.last?.first, last.reps == value.reps,
        last.repsChanged == value.repsChanged, last.loadChanged == value.loadChanged
      {
        groups[groups.count - 1].append(value)
      } else {
        groups.append([value])
      }
    }
    return Self(
      segments: groups.compactMap { group in
        guard var result = group.first else { return nil }
        result.reps = "\(group.count)×" + result.reps
        if group.allSatisfy(\.intensityOnly) {
          let loads = group.map(\.load)
          if loads.allSatisfy({ $0.hasPrefix("RPE ") }), Set(loads).count > 1 {
            result.load = "RPE " + loads.map { String($0.dropFirst(4)) }.joined(separator: "/")
          } else {
            result.load = compressed(loads)
          }
        } else {
          result.load = compressed(group.map(\.load))
        }
        return result
      })
  }

  private static func segment(
    _ row: TodayWorkoutSetRowDraft, commonEffort: String?, unit: UnitPreference, locale: Locale
  ) -> Segment {
    let recorded = row.hasSavedRecord || row.completed || row.isStudentAdded || row.isExtra
    let count = recorded ? row.actualReps : row.prescribed.reps
    let short =
      recorded && !row.isStudentAdded && !row.isExtra
      && (count ?? 0) < (row.prescribed.reps ?? 0)
    var reps = count.map(String.init) ?? "—"
    if short {
      reps += "/" + String(row.prescribed.reps ?? 0)
    } else if !recorded, let maximum = row.prescribed.repsMax {
      reps += "–\(maximum)"
    }
    if !recorded, row.prescribed.setType == .amrap { reps += "+" }
    let load = load(row, recorded: recorded, unit: unit, locale: locale)
    var text = load.text
    if !load.intensityOnly, let commonEffort { text += " · " + commonEffort }
    return Segment(
      reps: reps, load: text, intensityOnly: load.intensityOnly,
      repsChanged: recorded && count != row.prescribed.reps,
      loadChanged: recorded
        && (row.actualWeight != row.prescribed.weightKg
          || row.actualRPE != row.prescribed.rpe
          || actualEffort(row) != effort(row.prescribed)),
      shortReps: short)
  }

  private static func actualEffort(_ row: TodayWorkoutSetRowDraft) -> String? {
    if let rir = row.actualRIR { return "RIR \(rir)" }
    return row.actualRPE.map { "RPE " + StudentFormatting.decimal($0) }
  }

  private static func effort(_ set: PrescribedSet) -> String? {
    switch set.intensity {
    case .rpe(let value): return "RPE " + StudentFormatting.decimal(value)
    case .rir(let value): return "RIR \(value)"
    case .rpeRange(let low, let high):
      return "RPE \(StudentFormatting.decimal(low))–\(StudentFormatting.decimal(high))"
    default: return nil
    }
  }

  private static func load(
    _ row: TodayWorkoutSetRowDraft, recorded: Bool, unit: UnitPreference, locale: Locale
  ) -> (text: String, intensityOnly: Bool) {
    let set = row.prescribed
    func weight(_ value: Decimal?) -> String {
      value.map { UnitDisplay.weightText(kg: $0, unit: unit) } ?? "—"
    }
    if row.isBlankAddedRow {
      return (StudentStrings.localized(.allDayUnrecorded, locale: locale), false)
    }
    if recorded {
      if row.actualWeight == nil, let effort = actualEffort(row) { return (effort, true) }
      return (weight(row.actualWeight), false)
    }
    if set.isBodyweight {
      let name = StudentStrings.localized(.loadTypeBodyweight, locale: locale)
      return (name + (set.weightKg.map { "+" + weight($0) } ?? ""), false)
    }
    if set.loadMode == .freeWeight {
      return (StudentStrings.localized(.allDayFreeWeight, locale: locale), false)
    }
    if case .weightRange(let low, let high) = set.intensity {
      return (weight(low) + "–" + weight(high), false)
    }
    if case .percentage(let value) = set.intensity {
      let percentage = StudentFormatting.decimal(value) + "%"
      if let resolved = row.actualWeight {
        return (weight(resolved), false)
      }
      let suffix =
        set.effectivePercentageAnchor == .topSet
        ? " " + StudentStrings.localized(.allDayTopSet, locale: locale) : ""
      return (percentage + suffix, true)
    }
    if let prescribed = set.weightKg { return (weight(prescribed), false) }
    if let effort = effort(set) { return (effort, true) }
    return ("—", false)
  }

  private static func compressed(_ values: [String]) -> String {
    guard let first = values.first else { return "—" }
    if values.allSatisfy({ $0 == first }) { return first }
    var runs: [(String, Int)] = []
    for value in values {
      if runs.last?.0 == value { runs[runs.count - 1].1 += 1 } else { runs.append((value, 1)) }
    }
    return runs.map { $0.0 + ($0.1 > 1 ? "×\($0.1)" : "") }.joined(separator: " / ")
  }
}
