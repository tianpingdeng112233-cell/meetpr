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

  public struct SetRowDraft: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let planExerciseID: UUID
    /// Catalog exercise identity (variation-level) — spec 028 keys e1RM
    /// history and PR detection per exercise+variation, not per plan slot.
    public let exerciseID: UUID
    public let exerciseName: String
    public var prescribed: PrescribedSet
    public var actualWeight: Decimal?
    public var actualReps: Int?
    public var actualRPE: Decimal?
    public var completed: Bool
    public var loggedSetID: UUID?

    public init(
      id: UUID,
      planExerciseID: UUID,
      exerciseID: UUID,
      exerciseName: String,
      prescribed: PrescribedSet,
      actualWeight: Decimal? = nil,
      actualReps: Int? = nil,
      actualRPE: Decimal? = nil,
      completed: Bool = false,
      loggedSetID: UUID? = nil
    ) {
      self.id = id
      self.planExerciseID = planExerciseID
      self.exerciseID = exerciseID
      self.exerciseName = exerciseName
      self.prescribed = prescribed
      self.actualWeight = actualWeight
      self.actualReps = actualReps
      self.actualRPE = actualRPE
      self.completed = completed
      self.loggedSetID = loggedSetID
    }
  }

  public struct RestTimerState: Equatable, Sendable {
    /// Wall-clock end; remaining time stays correct across background trips.
    public let endsAt: Date
    /// Progress-bar denominator.
    public let totalSeconds: Int
  }

  public private(set) var state: State = .idle
  /// Set when a completed set breaks the exercise's e1RM record; the view
  /// presents PRBanner and calls `acknowledgePR` on dismiss (spec 028).
  public private(set) var pendingPRBanner: PRBreakthroughEvent?
  /// Inter-set rest countdown (spec 030 §B). Purely local, never persisted.
  public private(set) var restTimer: RestTimerState?

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let e1rmRepo: any E1RMRepository
  private let now: @Sendable () -> Date
  private var currentStudentID: UUID?

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
    state = .loading
    do {
      guard let day = try await plans.fetchDay(studentID: studentID, date: date) else {
        state = .rest
        return
      }
      let dayRange = Self.dayRange(containing: day.date)
      let existingLogs = try await logs.fetchLogs(studentID: studentID, in: dayRange)
      let drafts = day.exercises.flatMap { exercise in
        exercise.prescribedSets.map { set in
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
      }
      state = .loaded(plan: day, drafts: drafts)
    } catch {
      state = .error(error.localizedDescription)
    }
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
      try await logs.recordSet(log)
      draft.completed = completed
      draft.loggedSetID = log.id
      nextDrafts[rowIndex] = draft
      state = .loaded(plan: plan, drafts: nextDrafts)

      // Spec 028 hook: compute e1RM + detect PR only on the false→true edge,
      // so un-checking and re-checking the same set can't farm PR events.
      // Spec 030 rides the same edge for the rest timer.
      if !previouslyCompleted, completed {
        await recordE1RMPoint(for: draft, log: log, studentID: studentID)
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

  private func recordE1RMPoint(
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
    try? await e1rmRepo.recordPoint(point)

    let previousMax = try? await e1rmRepo.maxBefore(
      studentId: studentID,
      exerciseId: draft.exerciseID,
      before: point.computedAt
    )
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
      try? await e1rmRepo.recordPR(event)
      pendingPRBanner = event
    }
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

  private static func dayRange(containing date: Date) -> ClosedRange<Date> {
    let start = Calendar.current.startOfDay(for: date)
    return start...start.addingTimeInterval(86_400 - 1)
  }
}
