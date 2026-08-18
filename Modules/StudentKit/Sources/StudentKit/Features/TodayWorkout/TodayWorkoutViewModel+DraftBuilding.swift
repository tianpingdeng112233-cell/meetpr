import CoreModels
import Foundation

// MARK: - Draft building (pure): plan day + existing logs → set-row drafts.
// Split from TodayWorkoutViewModel.swift to keep that file inside the lint
// file_length budget (see specs/055 NOTES.md).
extension TodayWorkoutViewModel {
  func weightSuggestion(forSetID setID: UUID) -> SetWeightSuggestion? {
    weightSuggestionOutcome(forSetID: setID).suggestion
  }

  func weightSuggestionOutcome(forSetID setID: UUID) -> SetWeightSuggestionOutcome {
    guard let drafts = currentDrafts,
      let draft = drafts.first(where: { $0.id == setID })
    else {
      return .unavailableWithoutReason
    }
    return Self.weightSuggestionOutcome(
      forSetID: setID,
      in: drafts,
      currentE1RMKg: suggestionE1RMByExercise[draft.exerciseID],
      lastLoggedWeightKg: lastWeightByExercise[draft.exerciseID]
    )
  }

  nonisolated static func weightSuggestion(
    forSetID setID: UUID,
    in drafts: [SetRowDraft],
    currentE1RMKg: Double?,
    lastLoggedWeightKg: Decimal? = nil
  ) -> SetWeightSuggestion? {
    weightSuggestionOutcome(
      forSetID: setID,
      in: drafts,
      currentE1RMKg: currentE1RMKg,
      lastLoggedWeightKg: lastLoggedWeightKg
    ).suggestion
  }

  nonisolated static func weightSuggestionOutcome(
    forSetID setID: UUID,
    in drafts: [SetRowDraft],
    currentE1RMKg: Double?,
    lastLoggedWeightKg: Decimal? = nil
  ) -> SetWeightSuggestionOutcome {
    guard let targetIndex = drafts.firstIndex(where: { $0.id == setID }) else {
      return .unavailableWithoutReason
    }
    let target = drafts[targetIndex]
    guard target.prescribed.weightKg == nil else {
      return .unavailableWithoutReason
    }

    let baseOutcome =
      target.isMainLift
      ? mainLiftSuggestionOutcome(
        target: target,
        priorDrafts: drafts[..<targetIndex],
        currentE1RMKg: currentE1RMKg
      )
      : fallbackSuggestionOutcome(
        target: target, priorDrafts: drafts[..<targetIndex],
        lastLoggedWeightKg: lastLoggedWeightKg)
    guard let suggestion = baseOutcome.suggestion else { return baseOutcome }
    return suggestionOutcome(suggestion, for: target)
  }

  private nonisolated static func suggestionOutcome(
    _ suggestion: SetWeightSuggestion,
    for target: SetRowDraft
  ) -> SetWeightSuggestionOutcome {
    // Seed case: nothing logged yet. Rebuild case: the camera flow persists the
    // untouched seed into actualWeight (SetEntrySheet onWillPick) and the sheet
    // re-inits, so an incomplete set whose actual still equals the suggestion
    // is still in the suggested state; any other actual means the student took
    // over and the annotation must not resurface.
    if target.actualWeight == nil {
      return SetWeightSuggestionOutcome(suggestion: suggestion, unavailableReason: nil)
    }
    if !target.completed, target.actualWeight == suggestion.weightKg {
      return SetWeightSuggestionOutcome(suggestion: suggestion, unavailableReason: nil)
    }
    return .unavailableWithoutReason
  }

  private nonisolated static func mainLiftSuggestionOutcome(
    target: SetRowDraft,
    priorDrafts: ArraySlice<SetRowDraft>,
    currentE1RMKg: Double?
  ) -> SetWeightSuggestionOutcome {
    guard let targetRPE = target.prescribed.rpe else {
      return SetWeightSuggestionOutcome(
        suggestion: nil,
        unavailableReason: .missingPrescribedRPE
      )
    }
    guard let targetReps = target.prescribed.reps ?? target.prescribed.repsMax else {
      return SetWeightSuggestionOutcome(
        suggestion: nil,
        unavailableReason: .missingPrescribedReps
      )
    }
    guard (1...12).contains(targetReps) else {
      return SetWeightSuggestionOutcome(
        suggestion: nil,
        unavailableReason: .prescribedRepsOutsideSupportedRange
      )
    }
    let targetRPEDouble = NSDecimalNumber(decimal: targetRPE).doubleValue
    let rpeReason: SetWeightSuggestionUnavailableReason? =
      targetRPEDouble < 5
      ? .prescribedRPEBelowSupportedRange
      : targetRPEDouble > 10 ? .prescribedRPEAboveSupportedRange : nil
    guard rpeReason == nil else {
      return SetWeightSuggestionOutcome(suggestion: nil, unavailableReason: rpeReason)
    }
    let suggestion = mainLiftSuggestion(
      target: target,
      targetReps: targetReps,
      targetRPE: targetRPE,
      priorDrafts: priorDrafts,
      currentE1RMKg: currentE1RMKg
    )
    return SetWeightSuggestionOutcome(
      suggestion: suggestion,
      unavailableReason: suggestion == nil ? .noEligibleE1RMHistory : nil
    )
  }

  private nonisolated static func fallbackSuggestionOutcome(
    target: SetRowDraft,
    priorDrafts: ArraySlice<SetRowDraft>,
    lastLoggedWeightKg: Decimal?
  ) -> SetWeightSuggestionOutcome {
    let suggestion = fallbackSuggestion(
      target: target,
      priorDrafts: priorDrafts,
      lastLoggedWeightKg: lastLoggedWeightKg
    )
    return SetWeightSuggestionOutcome(
      suggestion: suggestion,
      unavailableReason: suggestion == nil ? .noExerciseHistory : nil
    )
  }

  /// Main lifts: same-day set with the identical prescription continues,
  /// otherwise reverse the RTS table from the current e1RM.
  private nonisolated static func mainLiftSuggestion(
    target: SetRowDraft,
    targetReps: Int,
    targetRPE: Decimal,
    priorDrafts: ArraySlice<SetRowDraft>,
    currentE1RMKg: Double?
  ) -> SetWeightSuggestion? {
    let previous = priorDrafts.reversed().first { candidate in
      candidate.exerciseID == target.exerciseID
        && candidate.completed
        && !candidate.failed
        && candidate.actualWeight.map { $0 > 0 } == true
        && (candidate.prescribed.reps ?? candidate.prescribed.repsMax) == targetReps
        && candidate.prescribed.rpe == targetRPE
    }
    if let previousWeight = previous?.actualWeight {
      return SetWeightSuggestion(weightKg: previousWeight, basis: .previousSet)
    }
    guard let currentE1RMKg,
      let rawWeight = E1RMCalculator.suggestedWeight(
        e1RM: currentE1RMKg,
        reps: targetReps,
        rpe: NSDecimalNumber(decimal: targetRPE).doubleValue
      )
    else { return nil }
    // Forward e1RMs are quotients (weight / intensity), so reversing can land
    // a hair under the exact multiple (49.999…); nudge before flooring or the
    // suggestion drops a whole 2.5 step.
    let steps = (rawWeight / 2.5 + 1e-6).rounded(.down)
    let roundedWeight = steps * 2.5
    guard roundedWeight > 0 else { return nil }
    return SetWeightSuggestion(weightKg: Decimal(roundedWeight), basis: .e1RM(currentE1RMKg))
  }

  /// Variations / accessories never get e1RM math: today's most recent
  /// completed set of the exercise (any prescription) continues, otherwise
  /// the last logged weight from an earlier session.
  private nonisolated static func fallbackSuggestion(
    target: SetRowDraft,
    priorDrafts: ArraySlice<SetRowDraft>,
    lastLoggedWeightKg: Decimal?
  ) -> SetWeightSuggestion? {
    let previous = priorDrafts.reversed().first { candidate in
      candidate.exerciseID == target.exerciseID
        && candidate.completed
        && !candidate.failed
        && candidate.actualWeight.map { $0 > 0 } == true
    }
    if let previousWeight = previous?.actualWeight {
      return SetWeightSuggestion(weightKg: previousWeight, basis: .previousSet)
    }
    guard let lastLoggedWeightKg, lastLoggedWeightKg > 0 else { return nil }
    return SetWeightSuggestion(weightKg: lastLoggedWeightKg, basis: .lastLogged)
  }

  /// Lookback window for the variation/accessory "last logged weight" fill.
  /// Ends one second BEFORE the viewed day's start — the range is inclusive
  /// (and the backend widens the end to a full day), so ending at 00:00 would
  /// leak the viewed day's own logs in; that day is covered by drafts instead.
  /// Bounds follow the device-local day; exact UTC wire-day alignment rides
  /// the gym-day day-boundary spec (harmless here — lastWeights takes the
  /// latest log, and same-day leaks lose to the drafts path anyway).
  nonisolated static func lastWeightHistoryRange(before dayDate: Date) -> ClosedRange<Date> {
    let dayStart = dayRange(containing: dayDate).lowerBound
    let lowerBound = dayStart.addingTimeInterval(-Double(lastWeightLookbackDays) * 86_400)
    return lowerBound...dayStart.addingTimeInterval(-1)
  }

  nonisolated static var lastWeightLookbackDays: Int { 84 }

  /// planExerciseID → catalog exerciseID for logs that predate the
  /// `StudentSetLog.exerciseID` field (legacy/demo rows).
  nonisolated static func planExerciseMap(
    plan: StudentPlanView?, day: StudentPlanDay
  ) -> [UUID: UUID] {
    var map: [UUID: UUID] = [:]
    for exercise in (plan?.days.flatMap(\.exercises) ?? []) + day.exercises {
      map[exercise.id] = exercise.exercise.id
    }
    return map
  }

  /// Most recent completed, non-failed logged weight per catalog exercise.
  nonisolated static func lastWeights(
    from logs: [StudentSetLog],
    planExerciseToExercise: [UUID: UUID]
  ) -> [UUID: Decimal] {
    var latest: [UUID: StudentSetLog] = [:]
    for log in logs where log.completed && !log.failed && log.weightKg > 0 {
      guard let exerciseID = log.exerciseID ?? planExerciseToExercise[log.planExerciseID] else {
        continue
      }
      if let current = latest[exerciseID],
        current.loggedAt > log.loggedAt
          || (current.loggedAt == log.loggedAt && current.setIndex > log.setIndex)
      {
        continue
      }
      latest[exerciseID] = log
    }
    return latest.mapValues(\.weightKg)
  }

  static func makeDrafts(
    for day: StudentPlanDay,
    existingLogs: [StudentSetLog]
  ) -> [SetRowDraft] {
    day.exercises.flatMap { exercise in
      exercise.prescribedSets.map { set in
        makeDraft(exercise: exercise, set: set, existingLogs: existingLogs)
      }
    }
  }

  static func makeDraft(
    exercise: StudentPlanExercise,
    set: PrescribedSet,
    existingLogs: [StudentSetLog]
  ) -> SetRowDraft {
    let existingLog = existingLogs.first {
      $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex
    }
    return SetRowDraft(
      id: set.id,
      planExerciseID: exercise.id,
      exerciseID: exercise.exercise.id,
      exerciseName: exercise.exercise.name,
      exerciseNameEn: exercise.exercise.nameEn,
      isAccessory: exercise.exercise.isAccessory,
      isMainLift: exercise.exercise.exerciseType == .mainLift,
      prescribed: set,
      actualWeight: existingLog?.weightKg ?? set.weightKg,
      actualReps: existingLog?.reps ?? set.reps,
      actualRPE: existingLog?.rpe ?? set.rpe ?? 8,
      completed: existingLog?.completed ?? false,
      failed: existingLog?.failed ?? false,
      assumed: existingLog?.assumed ?? false,
      loggedSetID: existingLog?.id
    )
  }
}
