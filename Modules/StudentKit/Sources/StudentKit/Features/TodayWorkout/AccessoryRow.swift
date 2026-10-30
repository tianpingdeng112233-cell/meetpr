import CoreModels
import Foundation

enum ActualEffortMode: String, Sendable {
  case rpe, rir
  var label: String { rawValue.uppercased() }
}

struct AccessoryInput: Equatable, Sendable {
  var weight: String
  var reps: String
  var rpe: String
  var effortMode: ActualEffortMode = .rpe
}

/// A display-unit editing buffer. Persisted drafts and wire values remain kilograms.
struct AccessoryRow: Equatable, Sendable, Identifiable {
  let draft: TodayWorkoutSetRowDraft
  let previous: StudentSetLog?
  let previousAdded: StudentAddedSetLog?
  var previousWeight: Decimal? { previous?.weightKg ?? previousAdded?.weightKg }
  var previousReps: Int? { previous?.reps ?? previousAdded?.reps }
  let unit: UnitPreference
  let hasVideo: Bool
  let initialInput: AccessoryInput
  var input: AccessoryInput

  var id: UUID { draft.id }
  var isBodyweight: Bool { draft.prescribed.isBodyweight }
  var extraNote: String? {
    draft.prescribed.visibleCoachNote
  }
  var isRecorded: Bool { draft.completed || draft.failed }
  var isCancellation: Bool { draft.completed && !draft.failed && input == initialInput }
  var weightPlaceholder: String { UnitDisplay.weightText(kg: previousWeight, unit: unit) }
  var rpePlaceholder: String {
    switch (input.effortMode, draft.prescribed.intensity) {
    case (.rir, .rir(let value)): String(value)
    case (.rpe, .rpe(let value)): SetEntryValue.text(value)
    default: ""
    }
  }
  mutating func switchEffort(to mode: ActualEffortMode) {
    guard draft.isAccessory, draft.loggedSetID == nil else { return }
    input.effortMode = mode
    input.rpe = ""
  }
  var rir: Int? {
    guard input.effortMode == .rir, let value = Int(input.rpe), (0...9).contains(value) else {
      return nil
    }
    return value
  }
  var weightKg: Decimal? {
    if isBodyweight && input.weight.trimmingCharacters(in: .whitespaces).isEmpty { return 0 }
    guard let value = Self.number(input.weight), value >= 0 else { return nil }
    return UnitDisplay.rounded(unit == .lb ? value / UnitDisplay.lbPerKg : value, scale: 2)
  }
  var reps: Int? {
    guard let value = Int(input.reps.trimmingCharacters(in: .whitespaces)),
      (1...99).contains(value)
    else { return nil }
    return value
  }
  var rpe: Decimal? {
    guard input.effortMode == .rpe, !input.rpe.isEmpty, let value = Self.number(input.rpe) else {
      return nil
    }
    return SetEntryValue.snapRPE(value)
  }
  var isRPEValid: Bool {
    input.rpe.isEmpty
      || (input.effortMode == .rir
        ? rir != nil : Self.number(input.rpe).map { (5...10).contains($0) } == true)
  }
  var isWritable: Bool { weightKg != nil && reps != nil && isRPEValid }

  init(
    draft: TodayWorkoutSetRowDraft, previous: StudentSetLog?, unit: UnitPreference,
    hasVideo: Bool = false, previousAdded: StudentAddedSetLog? = nil
  ) {
    self.draft = draft
    self.previous = previous
    self.previousAdded = previousAdded
    self.unit = unit
    self.hasVideo = hasVideo
    let input = AccessoryInput(
      weight: UnitDisplay.weightText(
        kg: draft.loggedSetID == nil && !draft.isExtra && !draft.isStudentAdded
          ? (draft.prescribed.isBodyweight ? 0 : draft.prescribed.weightKg) : draft.actualWeight,
        unit: unit),
      reps: (draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax).map(String.init)
        ?? "",
      rpe: draft.loggedSetID == nil
        ? "" : draft.actualRIR.map(String.init) ?? draft.actualRPE.map(SetEntryValue.text) ?? "",
      effortMode: draft.actualRIR != nil
        ? .rir
        : draft.loggedSetID != nil
          ? .rpe : draft.isAccessory && Self.hasRIRTarget(draft) ? .rir : .rpe
    )
    self.initialInput = input
    self.input = input
  }

  mutating func usePrevious() {
    guard let previousReps else { return }
    input.weight = UnitDisplay.weightText(kg: previousWeight, unit: unit)
    input.reps = String(previousReps)
  }

  static func selection(_ rows: [Self]) -> (writable: [Self], skipped: [Self]) {
    let pending = rows.filter { !$0.isRecorded && !$0.draft.isExtra && !$0.draft.isStudentAdded }
      .sorted {
        $0.draft.prescribed.setIndex < $1.draft.prescribed.setIndex
      }
    return (pending.filter(\.isWritable), pending.filter { !$0.isWritable })
  }

  private static func hasRIRTarget(_ draft: TodayWorkoutSetRowDraft) -> Bool {
    if case .rir = draft.prescribed.intensity { return true }
    return false
  }

  private static func number(_ text: String) -> Decimal? {
    let normalized = text.trimmingCharacters(in: .whitespaces).replacing(",", with: ".")
    guard normalized.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil else {
      return nil
    }
    return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
  }
}

struct AccessoryBatchResult: Equatable, Sendable {
  let written: Int
  let skipped: Int
  let failed: Bool
}
