import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class TodayWorkoutViewModel {
  public enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded(plan: StudentPlanDay, drafts: [SetRowDraft])
    case recording(plan: StudentPlanDay, drafts: [SetRowDraft], rowIndex: Int)
    case rest
    case error(String)
  }

  public typealias SetRowDraft = TodayWorkoutSetRowDraft

  public typealias RestTimerState = TodayWorkoutRestTimerState

  public private(set) var state: State = .idle
  /// Set when a completed set breaks the exercise's e1RM record; the view
  /// presents PRBanner and calls `acknowledgePR` on dismiss (spec 028).
  public private(set) var pendingPRBanner: PRBreakthroughEvent?
  /// Inter-set rest countdown (spec 030 §B). Purely local, never persisted.
  public private(set) var restTimer: RestTimerState?
  public private(set) var planContext: TodayWorkoutPlanContext?
  public private(set) var exerciseReferences: [UUID: ExerciseReference] = [:]

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let e1rmRepo: any E1RMRepository
  private let now: @Sendable () -> Date
  private var currentStudentID: UUID?
  private var loadGeneration = 0

  public init(
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.plans = plans
    self.logs = logs
    self.e1rmRepo = e1rm
    self.now = now
  }

  public func load(date: Date, studentID: UUID) async {
    currentStudentID = studentID
    loadGeneration += 1
    let generation = loadGeneration
    state = .loading
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      guard isCurrentLoad(generation) else { return }
      planContext = Self.planContext(from: plan, selectedDate: date)

      guard let day = try await loadDay(from: plan, date: date, studentID: studentID) else {
        guard isCurrentLoad(generation) else { return }
        exerciseReferences = [:]
        state = .rest
        return
      }
      let dayRange = Self.dayRange(containing: day.date)
      let existingLogs = try await logs.fetchLogs(studentID: studentID, in: dayRange)
      let drafts = Self.makeDrafts(for: day, existingLogs: existingLogs)
      let references = try await exerciseReferences(for: day, studentID: studentID)
      guard isCurrentLoad(generation) else { return }
      exerciseReferences = references
      state = .loaded(plan: day, drafts: drafts)
    } catch {
      if isCurrentLoad(generation) {
        state = .error(error.localizedDescription)
      }
    }
  }

  private func loadDay(
    from plan: StudentPlanView?,
    date: Date,
    studentID: UUID
  ) async throws -> StudentPlanDay? {
    if let day = plan?.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
      return day
    }
    return try await plans.fetchDay(studentID: studentID, date: date)
  }

  public func updateWeight(rowIndex: Int, weight: Decimal?) {
    mutateDraft(rowIndex: rowIndex) { $0.actualWeight = weight }
  }

  public func updateReps(rowIndex: Int, reps: Int?) {
    mutateDraft(rowIndex: rowIndex) { $0.actualReps = reps }
  }

  public func updateRPE(rowIndex: Int, rpe: Decimal?) {
    mutateDraft(rowIndex: rowIndex) { $0.actualRPE = rpe }
  }

  public func toggleComplete(rowIndex: Int) async {
    guard case .loaded(_, let drafts) = state, drafts.indices.contains(rowIndex) else {
      return
    }
    await persist(rowIndex: rowIndex, completed: !drafts[rowIndex].completed)
  }

  /// Persists the row's current draft values and marks it complete. Used by the
  /// set-entry sheet for both first completion and edits to an already-completed
  /// set (the latter must still hit `recordSet`, or the edit is lost on reload).
  public func commitSet(rowIndex: Int) async {
    await persist(rowIndex: rowIndex, completed: true)
  }

  /// Returns the row's set-log id, recording the draft first (with its
  /// current completion state, so attaching a video never marks a set done)
  /// when it has never been logged. Video attachments need a set-log identity
  /// before upload (spec 027).
  public func ensureLoggedSetID(rowIndex: Int) async -> UUID? {
    guard case .loaded(_, let drafts) = state, drafts.indices.contains(rowIndex) else {
      return nil
    }
    if let loggedSetID = drafts[rowIndex].loggedSetID {
      return loggedSetID
    }
    await persist(rowIndex: rowIndex, completed: drafts[rowIndex].completed)
    guard case .loaded(_, let updated) = state, updated.indices.contains(rowIndex) else {
      return nil
    }
    return updated[rowIndex].loggedSetID
  }

  private func persist(rowIndex: Int, completed: Bool) async {
    guard let studentID = currentStudentID else {
      state = .error("Missing student")
      return
    }
    guard case .loaded(let plan, let drafts) = state, drafts.indices.contains(rowIndex) else {
      return
    }
    var nextDrafts = drafts
    var draft = nextDrafts[rowIndex]
    state = .recording(plan: plan, drafts: nextDrafts, rowIndex: rowIndex)

    let log = StudentSetLog(
      id: draft.loggedSetID ?? UUID(),
      studentID: studentID,
      planExerciseID: draft.planExerciseID,
      setIndex: draft.prescribed.setIndex,
      loggedAt: now(),
      weightKg: draft.actualWeight ?? draft.prescribed.weightKg ?? 0,
      reps: draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax ?? 0,
      rpe: draft.actualRPE,
      completed: completed
    )

    do {
      let previouslyCompleted = drafts[rowIndex].completed
      // The repository returns the canonical (backend-upserted) log: its id
      // is what video linkage and e1RM points must reference (Codex P1).
      let persisted = try await logs.recordSet(log)
      draft.completed = completed
      draft.loggedSetID = persisted.id
      nextDrafts[rowIndex] = draft
      state = .loaded(plan: plan, drafts: nextDrafts)

      // Spec 028 hook: compute e1RM + detect PR only on the false→true edge,
      // so un-checking and re-checking the same set can't farm PR events.
      // Spec 030 rides the same edge for the rest timer.
      if !previouslyCompleted, completed {
        await recordE1RMPoint(for: draft, log: persisted, studentID: studentID)
        startRestTimer(after: draft, drafts: nextDrafts)
      }
    } catch {
      state = .error(error.localizedDescription)
    }
  }

  public func adjustRestTimer(bySeconds delta: Int) {
    guard let timer = restTimer else { return }
    let remaining = timer.endsAt.timeIntervalSince(now()) + TimeInterval(delta)
    let clamped = min(max(remaining, 0), 900)
    restTimer = RestTimerState(
      endsAt: now().addingTimeInterval(clamped), totalSeconds: timer.totalSeconds)
  }

  public func skipRestTimer() {
    restTimer = nil
  }

  private func startRestTimer(after draft: SetRowDraft, drafts: [SetRowDraft]) {
    // Last set of the day: the completion banner takes over, a countdown is noise.
    guard !drafts.allSatisfy(\.completed) else {
      restTimer = nil
      return
    }
    let seconds = RestTimerPolicy.restSeconds(forRPE: draft.actualRPE)
    restTimer = RestTimerState(
      endsAt: now().addingTimeInterval(TimeInterval(seconds)), totalSeconds: seconds)
  }

  public func exerciseName(for exerciseId: UUID) -> String? {
    switch state {
    case .loaded(_, let drafts), .recording(_, let drafts, _):
      drafts.first { $0.exerciseID == exerciseId }?.exerciseName
    default:
      nil
    }
  }

  public func acknowledgePendingPR() async {
    guard let event = pendingPRBanner else { return }
    pendingPRBanner = nil
    try? await e1rmRepo.acknowledgePR(eventId: event.id)
  }

  /// Surfaces the oldest unacknowledged PR on launch so a banner the student
  /// missed (e.g. app killed mid-session) re-appears once (spec 028 §5).
  public func surfaceUnacknowledgedPR(studentID: UUID) async {
    guard pendingPRBanner == nil else { return }
    pendingPRBanner = (try? await e1rmRepo.unacknowledgedPRs(studentId: studentID))?.first
  }

  private func mutateDraft(rowIndex: Int, update: (inout SetRowDraft) -> Void) {
    switch state {
    case .loaded(let plan, let drafts), .recording(let plan, let drafts, _):
      guard drafts.indices.contains(rowIndex) else {
        return
      }
      var nextDrafts = drafts
      update(&nextDrafts[rowIndex])
      state = .loaded(plan: plan, drafts: nextDrafts)
    default:
      return
    }
  }

  private func isCurrentLoad(_ generation: Int) -> Bool {
    generation == loadGeneration
  }

  private static func planContext(
    from plan: StudentPlanView?,
    selectedDate: Date
  ) -> TodayWorkoutPlanContext? {
    guard let plan else { return nil }
    return TodayWorkoutPlanContext(
      planKind: plan.planKind,
      weekIndex: weekIndex(for: selectedDate, startDate: plan.startDate, fallback: plan.weekIndex),
      startDate: plan.startDate
    )
  }

  private static func weekIndex(for date: Date, startDate: Date, fallback: Int) -> Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: startDate)
    let selected = calendar.startOfDay(for: date)
    guard let elapsedDays = calendar.dateComponents([.day], from: start, to: selected).day else {
      return fallback
    }
    return max(1, elapsedDays / 7 + 1)
  }

  private static func dayRange(containing date: Date) -> ClosedRange<Date> {
    let start = Calendar.current.startOfDay(for: date)
    return start...start.addingTimeInterval(86_400 - 1)
  }
}

// MARK: - Draft building & e1RM/PR side effects

@available(iOS 17.0, macOS 14.0, *)
extension TodayWorkoutViewModel {
  func exerciseReferences(
    for day: StudentPlanDay,
    studentID: UUID
  ) async throws -> [UUID: ExerciseReference] {
    let exerciseIDs = Set(day.exercises.map(\.exercise.id))
    let e1rmRepo = self.e1rmRepo
    return try await withThrowingTaskGroup(of: (UUID, ExerciseReference?).self) { group in
      for exerciseID in exerciseIDs {
        group.addTask {
          let points = try await e1rmRepo.fetchHistory(studentId: studentID, exerciseId: exerciseID)
          let selected = lastAndBest(from: points)
          let reference = ExerciseReference(
            last: selected.last.map(ExerciseReferenceSet.init(point:)),
            best: selected.best.map(ExerciseReferenceSet.init(point:))
          )
          return (exerciseID, reference.hasValue ? reference : nil)
        }
      }

      var references: [UUID: ExerciseReference] = [:]
      for try await (exerciseID, reference) in group {
        if let reference {
          references[exerciseID] = reference
        }
      }
      return references
    }
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
      prescribed: set,
      actualWeight: existingLog?.weightKg ?? set.weightKg,
      actualReps: existingLog?.reps ?? set.reps,
      actualRPE: existingLog?.rpe ?? set.rpe ?? 8,
      completed: existingLog?.completed ?? false,
      loggedSetID: existingLog?.id
    )
  }

  func recordE1RMPoint(
    for draft: SetRowDraft,
    log: StudentSetLog,
    studentID: UUID
  ) async {
    let weight = NSDecimalNumber(decimal: log.weightKg).doubleValue
    let rpe = draft.actualRPE.map { NSDecimalNumber(decimal: $0).doubleValue }
    guard
      let estimatedOneRepMaxKg = E1RMCalculator.calculate(
        weightKg: weight,
        reps: log.reps,
        rpe: rpe
      )
    else { return }

    let point = E1RMHistoryPoint(
      id: UUID(),
      studentId: studentID,
      exerciseId: draft.exerciseID,
      setLogId: log.id,
      computedAt: now(),
      e1RMKg: estimatedOneRepMaxKg,
      sourceWeightKg: weight,
      sourceReps: log.reps,
      sourceRPE: rpe
    )
    do {
      // Baseline BEFORE inserting the new point, over the full history
      // (.distantFuture): a strictly-earlier filter at point.computedAt would
      // miss a same-timestamp sibling and double-fire PRs (Codex review P1).
      let previousMax = try await e1rmRepo.maxBefore(
        studentId: studentID,
        exerciseId: draft.exerciseID,
        before: .distantFuture
      )
      try await e1rmRepo.recordPoint(point)

      // 0.5kg buffer absorbs float jitter; tune to 1.0 if PRs fire too often.
      if estimatedOneRepMaxKg > (previousMax ?? 0) + 0.5 {
        let event = PRBreakthroughEvent(
          id: UUID(),
          studentId: studentID,
          exerciseId: draft.exerciseID,
          pointId: point.id,
          breakthroughE1RMKg: estimatedOneRepMaxKg,
          previousMaxE1RMKg: previousMax ?? 0,
          occurredAt: point.computedAt,
          acknowledgedAt: nil
        )
        try await e1rmRepo.recordPR(event)
        pendingPRBanner = event
      }
    } catch {
      // e1RM persistence is best-effort and must never block set logging,
      // but a banner only celebrates durably recorded history.
    }
  }
}
