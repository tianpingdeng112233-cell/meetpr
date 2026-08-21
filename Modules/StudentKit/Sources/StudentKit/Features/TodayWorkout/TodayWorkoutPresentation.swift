// swiftlint:disable file_length
import CoreModels
import DesignSystem
import Foundation

struct TodayWorkoutProgress: Equatable, Sendable {
  let remainingSets: Int
  let remainingExercises: Int
  let currentSetNumber: Int
  let currentSetTotal: Int
  let currentExerciseNumber: Int
  let exerciseTotal: Int
  let allDone: Bool

  init(day: StudentPlanDay, drafts: [TodayWorkoutViewModel.SetRowDraft]) {
    let active = drafts.first { !$0.completed }
    let current = active ?? drafts.last
    let exerciseIDs = day.exercises.map(\.id)
    let currentExerciseIndex =
      current.flatMap { draft in exerciseIDs.firstIndex(of: draft.planExerciseID) }
      ?? max(exerciseIDs.count - 1, 0)
    let exerciseDrafts =
      current.map { draft in
        drafts.filter { $0.planExerciseID == draft.planExerciseID }
      } ?? []
    let currentSetIndex =
      current.flatMap { draft in exerciseDrafts.firstIndex { $0.id == draft.id } }
      ?? max(exerciseDrafts.count - 1, 0)

    self.remainingSets = drafts.filter { !$0.completed }.count
    self.remainingExercises =
      day.exercises.filter { exercise in
        drafts.contains { $0.planExerciseID == exercise.id && !$0.completed }
      }.count
    self.currentSetNumber = min(currentSetIndex + 1, max(exerciseDrafts.count, 1))
    self.currentSetTotal = exerciseDrafts.count
    self.currentExerciseNumber = min(currentExerciseIndex + 1, max(exerciseIDs.count, 1))
    self.exerciseTotal = exerciseIDs.count
    self.allDone = remainingSets == 0
  }

  var remainingText: String {
    StudentStrings.replacing(
      .todayWorkoutPresentation001, values: ["\(remainingExercises)", "\(remainingSets)"])
  }

  var positionText: String {
    StudentStrings.replacing(
      .todayWorkoutPresentation002, values: ["\(currentSetNumber)", "\(currentSetTotal)"])
      + StudentStrings.replacing(
        .todayWorkoutPresentation003, values: ["\(currentExerciseNumber)", "\(exerciseTotal)"])
  }
}

// swiftlint:disable:next type_body_length
struct TodayWorkoutPresentation: Equatable, Sendable {
  enum HeroMode: Equatable, Sendable {
    case list
    case recording
  }

  struct Exercise: Equatable, Sendable, Identifiable {
    let id: UUID
    let stableIndex: Int
    let name: String
    let reference: String
    let cardSubtitle: String
    let note: String
    let rows: [Row]

    var allRecorded: Bool {
      !rows.isEmpty && rows.allSatisfy { $0.record.status != .pending }
    }

    /// New-form rows summarize the prescription; all-legacy exercises return
    /// nil so the screen keeps its pre-072 record-based summary (spec 072
    /// §1.4). Sets may be heterogeneous (spec §2): only a uniform prescription
    /// may be named, anything mixed shows just the set count instead of
    /// passing the first set off as all of them.
    var prescriptionSummary: String? {
      guard rows.contains(where: { !$0.draft.prescribed.isLegacyPrescription }) else {
        return nil
      }
      let renderings = Set(
        rows.map {
          StudentFormatting.prescribed(
            $0.draft.prescribed,
            percentageOutcome: $0.suggestionOutcome
          )
        }
      )
      guard renderings.count == 1, let uniform = renderings.first else {
        return StudentStrings.replacing(.todayWorkoutScreen019, values: ["\(rows.count)"])
      }
      let setsLabel = StudentStrings.replacing(.todayWorkoutScreen019, values: ["\(rows.count)"])
      return "\(uniform) · \(setsLabel)"
    }
  }

  struct Row: Equatable, Sendable, Identifiable {
    let id: UUID
    let stableIndex: Int
    let record: ExerciseSetRecord
    let draft: TodayWorkoutViewModel.SetRowDraft
    let suggestionOutcome: SetWeightSuggestionOutcome?

    /// Legacy rows keep the pre-072 hero exactly: record weight (or a dash)
    /// on top and the 目标 RPE block below (spec 072 §1.4).
    var usesLegacyHero: Bool {
      draft.prescribed.isLegacyPrescription
    }

    var heroPrimaryText: String {
      guard !usesLegacyHero else {
        return record.weight.map(Self.numberText) ?? "—"
      }
      if let weight = record.weight {
        return Self.numberText(weight)
      }
      if let prescriptionDisplay = record.prescriptionDisplay {
        return prescriptionDisplay.weightPrimary
      }
      if let suggestion = suggestionOutcome?.suggestion,
        case .percentage = suggestion.basis
      {
        return StudentStrings.replacing(
          .todayWorkoutTypes019,
          values: [StudentFormatting.decimal(suggestion.weightKg)]
        )
      }
      if case .percentage(let value) = draft.prescribed.intensity,
        let suggestionOutcome
      {
        return StudentFormatting.percentagePresentation(
          set: draft.prescribed,
          actualWeight: draft.actualWeight,
          outcome: suggestionOutcome
        )?.weightPrimary ?? StudentFormatting.decimal(value) + "%"
      }
      return draft.prescribed.intensity.map(StudentFormatting.intensityText) ?? "—"
    }

    var heroShowsWeightUnit: Bool {
      record.weight != nil || record.prescriptionDisplay?.weightUnit != nil
    }

    var heroSecondaryIntensityText: String? {
      guard !usesLegacyHero else { return nil }
      if let prescriptionDisplay = record.prescriptionDisplay {
        return prescriptionDisplay.weightSecondary
      }
      if case .percentage = draft.prescribed.intensity,
        let suggestionOutcome,
        let percentage = StudentFormatting.percentagePresentation(
          set: draft.prescribed,
          actualWeight: draft.actualWeight,
          outcome: suggestionOutcome
        )
      {
        return percentage.weightSecondary
      }
      guard heroShowsWeightUnit else { return nil }
      return draft.prescribed.intensity.map(StudentFormatting.intensityText)
    }

    var heroSecondaryLabelText: String? {
      guard !usesLegacyHero else { return nil }
      if record.prescriptionDisplay != nil { return nil }
      if case .percentage = draft.prescribed.intensity { return nil }
      return heroSecondaryIntensityText == nil
        ? nil
        : StudentStrings.localized(.todayWorkoutScreen027)
    }

    private static func numberText(_ value: Double) -> String {
      value.formatted(.number.precision(.fractionLength(0...2)))
    }
  }

  let day: StudentPlanDay
  let heroMode: HeroMode
  let exercises: [Exercise]
  let progress: TodayWorkoutProgress
  let currentRow: Row?
  /// A set that reached the server (or Demo store), failed attempts included.
  let hasAnyLoggedSet: Bool

  // There is no "skip this day" in sequence progression — an untouched day just
  // keeps the cursor. Manual completion is only offered once real work exists
  // (David 2026-08-07: hold button must not appear before any set is recorded).
  var allowsManualCompletion: Bool {
    heroMode == .recording && hasAnyLoggedSet
  }

  init(
    day: StudentPlanDay,
    drafts: [TodayWorkoutViewModel.SetRowDraft],
    references: [UUID: ExerciseReference],
    videoStates: [UUID: SetRow.VideoState] = [:],
    suggestionOutcomes: [UUID: SetWeightSuggestionOutcome] = [:],
    started: Bool
  ) {
    // The summary card IS the pre-start state, and it only belongs to a day
    // with zero recorded sets: tapping 开始第一组 or having ≥1 real recorded
    // set (failed included) means the session has started, and re-entry —
    // cold launch included — resumes the recording card directly (David
    // 2026-08-08 三次收敛). Assumed imported-history rows are not session
    // evidence; completed days are read-only detail via server `completedAt`.
    let hasSessionLog = drafts.contains {
      !$0.assumed && ($0.completed || $0.failed)
    }
    self.day = day
    self.hasAnyLoggedSet = hasSessionLog
    self.heroMode =
      started || hasSessionLog || day.completedAt != nil ? .recording : .list
    self.progress = TodayWorkoutProgress(day: day, drafts: drafts)

    // Top-set anchors resolve across rows (spec 034 §9.4): the back-off card
    // needs its anchor row, and that row — usually a separate card — needs the
    // "today's top set" marking. Resolve once per card, then index by draft.
    let topSetTargets = Dictionary(
      uniqueKeysWithValues: day.exercises.compactMap { exercise in
        let exerciseDrafts = drafts.filter { $0.planExerciseID == exercise.id }
        return Self.topSetTarget(for: exerciseDrafts, in: drafts).map { (exercise.id, $0) }
      }
    )
    let topSetRPEByDraftID = Dictionary(
      topSetTargets.values.map { ($0.id, $0.rpe) },
      uniquingKeysWith: { first, _ in first }
    )
    self.exercises = day.exercises.enumerated().map { exerciseIndex, exercise in
      let exerciseDrafts = drafts.filter { $0.planExerciseID == exercise.id }
      let topSetTarget = topSetTargets[exercise.id]
      let rows = exerciseDrafts.map { draft in
        let suggestionOutcome = suggestionOutcomes[draft.id]
        let markedTopSet = topSetRPEByDraftID[draft.id].map { (id: draft.id, rpe: $0) }
        return Row(
          id: draft.id,
          stableIndex: drafts.firstIndex { $0.id == draft.id } ?? 0,
          record: Self.record(
            from: draft,
            index: SetDisplayNumber.number(for: draft),
            videoState: draft.loggedSetID.flatMap { videoStates[$0] } ?? .none,
            prescriptionDisplay: Self.prescriptionDisplay(
              for: draft,
              suggestionOutcome: suggestionOutcome,
              topSetTarget: markedTopSet
            )
          ),
          draft: draft,
          suggestionOutcome: suggestionOutcome
        )
      }
      let reference = Self.referenceText(references[exercise.exercise.id])
      return Exercise(
        id: exercise.id,
        stableIndex: exerciseIndex,
        name: StudentExerciseName.display(exercise.exercise),
        reference: reference,
        cardSubtitle: Self.cardSubtitle(
          for: exerciseDrafts,
          outcomes: suggestionOutcomes,
          topSetTarget: topSetTarget
        ) ?? reference,
        note: CoachNoteDisplay.text(exercise.notes) ?? "",
        rows: rows
      )
    }
    self.currentRow =
      exercises.flatMap(\.rows).first { !$0.draft.completed }
      ?? exercises.flatMap(\.rows).last
  }

  static func record(
    from draft: TodayWorkoutViewModel.SetRowDraft,
    index: Int,
    videoState: SetRow.VideoState,
    prescriptionDisplay: ExerciseSetRecord.PrescriptionDisplay? = nil
  ) -> ExerciseSetRecord {
    ExerciseSetRecord(
      index: index,
      weight: optionalDecimalDouble(draft.actualWeight ?? draft.prescribed.weightKg),
      reps: draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax ?? 0,
      rpe: decimalDouble(draft.actualRPE ?? draft.prescribed.rpe ?? 0),
      status: draft.failed ? .failed : (draft.completed ? .done : .pending),
      videoState: videoState,
      indexAccessibilityIdentifier: "todayWorkout.set.\(draft.id.uuidString).number",
      prescriptionDisplay: prescriptionDisplay
    )
  }

  private static func topSetTarget(
    for exerciseDrafts: [TodayWorkoutViewModel.SetRowDraft],
    in allDrafts: [TodayWorkoutViewModel.SetRowDraft]
  ) -> (id: UUID, rpe: Decimal)? {
    guard
      let firstBackoffIndex = exerciseDrafts.firstIndex(where: {
        if case .percentage = $0.prescribed.intensity {
          return $0.prescribed.effectivePercentageAnchor == .topSet
        }
        return false
      })
    else { return nil }
    let backoff = exerciseDrafts[firstBackoffIndex]

    // The web editor keys load_mode per row, so the top set the coach meant is
    // the nearest preceding row of the same exercise (mirrors PctAnchorResolver).
    // Earlier sets inside the same card remain a fallback for hand-built plans.
    let precedingRows = allDrafts.filter {
      $0.exerciseID == backoff.exerciseID
        && $0.planExerciseSortOrder < backoff.planExerciseSortOrder
    }
    let sameCardEarlierSets = Array(exerciseDrafts[..<firstBackoffIndex])
    return (sameCardEarlierSets + precedingRows).reversed().compactMap { draft in
      draft.prescribed.rpe.map { (draft.id, $0) }
    }.first
  }

  private static func prescriptionDisplay(
    for draft: TodayWorkoutViewModel.SetRowDraft,
    suggestionOutcome: SetWeightSuggestionOutcome?,
    topSetTarget: (id: UUID, rpe: Decimal)?
  ) -> ExerciseSetRecord.PrescriptionDisplay? {
    let rpeText =
      (draft.completed || draft.failed ? draft.actualRPE : draft.prescribed.rpe)
      .map(StudentFormatting.decimal) ?? "—"

    if let topSetTarget, topSetTarget.id == draft.id {
      return ExerciseSetRecord.PrescriptionDisplay(
        weightPrimary: StudentStrings.localized(.todayWorkoutTypes024),
        weightSecondary: StudentStrings.replacing(
          .todayWorkoutTypes025,
          values: [StudentFormatting.decimal(topSetTarget.rpe)]
        ),
        rpeText: StudentFormatting.decimal(topSetTarget.rpe),
        emphasis: .primary
      )
    }

    guard case .percentage = draft.prescribed.intensity else { return nil }
    let percentage = StudentFormatting.percentagePresentation(
      set: draft.prescribed,
      actualWeight: draft.actualWeight,
      outcome: suggestionOutcome ?? .unavailableWithoutReason
    )
    guard let percentage else { return nil }
    return ExerciseSetRecord.PrescriptionDisplay(
      weightPrimary: percentage.weightPrimary,
      weightUnit: percentage.weightUnit,
      weightSecondary: percentage.weightSecondary,
      rpeText: rpeText,
      emphasis: percentage.isMuted ? .muted : .primary
    )
  }

  private static func cardSubtitle(
    for drafts: [TodayWorkoutViewModel.SetRowDraft],
    outcomes: [UUID: SetWeightSuggestionOutcome],
    topSetTarget: (id: UUID, rpe: Decimal)?
  ) -> String? {
    guard
      drafts.contains(where: {
        if case .percentage = $0.prescribed.intensity { return true }
        return false
      })
    else { return nil }

    if let topSetTarget,
      drafts.contains(where: { $0.prescribed.effectivePercentageAnchor == .topSet })
    {
      return StudentStrings.replacing(
        .todayWorkoutTypes022,
        values: [StudentFormatting.decimal(topSetTarget.rpe)]
      )
    }

    if drafts.allSatisfy({ $0.liftFamily == nil }) {
      return StudentStrings.localized(.todayWorkoutTypes023)
    }

    guard let source = drafts.compactMap({ outcomes[$0.id]?.percentageSource }).first,
      let anchorKg = source.anchorKg
    else { return nil }
    let anchor = StudentFormatting.decimal(anchorKg)
    switch source {
    case .registeredOneRM, .fallbackToRegisteredOneRM:
      return StudentStrings.replacing(.todayWorkoutTypes020, values: [anchor])
    case .e1RM:
      return StudentStrings.replacing(.todayWorkoutTypes021, values: [anchor])
    case .topSet, .unresolved:
      return nil
    }
  }

  private static func referenceText(_ reference: ExerciseReference?) -> String {
    guard let reference else { return "" }
    var parts: [String] = []
    if let last = reference.last {
      parts.append(
        StudentStrings.replacing(
          .todayWorkoutPresentation004, values: ["\(numberText(last.weightKg))", "\(last.reps)"]))
    }
    if let best = reference.best {
      parts.append(
        StudentStrings.replacing(
          .todayWorkoutPresentation005, values: ["\(numberText(best.weightKg))", "\(best.reps)"]))
    }
    return parts.joined(separator: " · ")
  }

  private static func optionalDecimalDouble(_ value: Decimal?) -> Double? {
    value.map { NSDecimalNumber(decimal: $0).doubleValue }
  }

  private static func decimalDouble(_ value: Decimal?) -> Double {
    optionalDecimalDouble(value) ?? 0
  }

  private static func numberText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

enum TodayWorkoutContentPolicy {
  static func isRestDay(_ day: StudentPlanDay) -> Bool {
    day.exercises.isEmpty
  }
}

struct TrainingCalendarScrollState: Equatable, Sendable {
  static let collapseOffset: CGFloat = 56
  static let expandOffset: CGFloat = 6
  static let minimumSlack: CGFloat = 200

  let isOpen: Bool

  func updating(offset: CGFloat, contentSlack: CGFloat) -> Self {
    if isOpen, contentSlack > Self.minimumSlack, offset > Self.collapseOffset {
      return Self(isOpen: false)
    }
    if !isOpen, offset < Self.expandOffset {
      return Self(isOpen: true)
    }
    return self
  }
}
