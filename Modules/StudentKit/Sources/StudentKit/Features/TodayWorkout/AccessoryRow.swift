import CoreModels
import Foundation

struct AccessoryInput: Equatable, Sendable {
  var weight: String
  var reps: String
  var rpe: String
}

/// A display-unit editing buffer. Persisted drafts and wire values remain kilograms.
struct AccessoryRow: Equatable, Sendable, Identifiable {
  let draft: TodayWorkoutSetRowDraft
  let previous: StudentSetLog?
  let unit: UnitPreference
  let hasVideo: Bool
  let initialInput: AccessoryInput
  var input: AccessoryInput

  var id: UUID { draft.id }
  var isBodyweight: Bool {
    let note = draft.prescribed.coachNote ?? ""
    return note.localizedStandardContains("bodyweight") || note.contains("自重")
  }
  var extraNote: String? {
    isBodyweight ? nil : CoachNoteDisplay.text(draft.prescribed.coachNote)
  }
  var isRecorded: Bool { draft.completed || draft.failed }
  var isCancellation: Bool { draft.completed && !draft.failed && input == initialInput }
  var weightPlaceholder: String { UnitDisplay.weightText(kg: previous?.weightKg, unit: unit) }
  var rpePlaceholder: String {
    switch draft.prescribed.intensity {
    case .rir(let value): "RIR \(value)"
    case .rpe(let value): SetEntryValue.text(value)
    default: draft.prescribed.rpe.map(SetEntryValue.text) ?? ""
    }
  }
  var weightKg: Decimal? {
    if isBodyweight { return 0 }
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
    guard !input.rpe.isEmpty, let value = Self.number(input.rpe) else { return nil }
    return SetEntryValue.snapRPE(value)
  }
  var isRPEValid: Bool {
    input.rpe.isEmpty || Self.number(input.rpe).map { (5...10).contains($0) } == true
  }
  var isWritable: Bool { weightKg != nil && reps != nil && isRPEValid }

  init(
    draft: TodayWorkoutSetRowDraft, previous: StudentSetLog?, unit: UnitPreference,
    hasVideo: Bool = false
  ) {
    self.draft = draft
    self.previous = previous
    self.unit = unit
    self.hasVideo = hasVideo
    let input = AccessoryInput(
      weight: UnitDisplay.weightText(
        kg: draft.loggedSetID == nil ? draft.prescribed.weightKg : draft.actualWeight, unit: unit),
      reps: (draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax).map(String.init)
        ?? "",
      rpe: draft.loggedSetID == nil ? "" : draft.actualRPE.map(SetEntryValue.text) ?? ""
    )
    self.initialInput = input
    self.input = input
  }

  mutating func usePrevious() {
    guard let previous else { return }
    if !isBodyweight { input.weight = UnitDisplay.weightText(kg: previous.weightKg, unit: unit) }
    input.reps = String(previous.reps)
  }

  static func selection(_ rows: [Self]) -> (writable: [Self], skipped: [Self]) {
    let pending = rows.filter { !$0.isRecorded }.sorted {
      $0.draft.prescribed.setIndex < $1.draft.prescribed.setIndex
    }
    return (pending.filter(\.isWritable), pending.filter { !$0.isWritable })
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
