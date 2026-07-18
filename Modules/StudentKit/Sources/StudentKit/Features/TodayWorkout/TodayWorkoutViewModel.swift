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
  public internal(set) var pendingPRBanner: PRBreakthroughEvent?
  /// Inter-set rest countdown (spec 030 §B). Purely local, never persisted.
  public private(set) var restTimer: RestTimerState?
  public private(set) var planContext: TodayWorkoutPlanContext?
  public private(set) var exerciseReferences: [UUID: ExerciseReference] = [:]
  public internal(set) var sessionPage: TodayWorkoutSessionPage = .loading
  public private(set) var lastCompletedDurationSeconds: Int?

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  let e1rmRepo: any E1RMRepository
  private let onboarding: any OnboardingProfileReading
  let sessions: any TrainingSessionRepository
  let now: @Sendable () -> Date
  let recentCompletedDurationStore: any RecentCompletedSessionDurationStoring
  var currentStudentID: UUID?
  var currentOnboarding: OnboardingProfile?
  var loadGeneration = 0
  var sessionStartGeneration = 0
  var viewingToday = true
  var currentGymDay: String?
  var localSessionOverride: LocalSessionOverride?
  var sessionStartTask: Task<Void, Never>?

  public init(
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    onboarding: any OnboardingProfileReading = InMemoryOnboardingRepository(studentId: UUID()),
    sessions: any TrainingSessionRepository = InMemoryTrainingSessionRepository(),
    recentCompletedDurationStore: any RecentCompletedSessionDurationStoring =
      UserDefaultsSessionDurationStore(),
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.plans = plans
    self.logs = logs
    self.e1rmRepo = e1rm
    self.onboarding = onboarding
    self.sessions = sessions
    self.recentCompletedDurationStore = recentCompletedDurationStore
    self.now = now
  }

  public func load(date: Date, sessionDate: Date? = nil, studentID: UUID) async {
    currentStudentID = studentID
    loadGeneration += 1
    let generation = loadGeneration
    let issuedStartGeneration = sessionStartGeneration
    viewingToday = sessionDate == nil
    state = .loading
    sessionPage =
      sessionDate == nil
      ? localSessionOverride.map { Self.resolveSessionPage(for: $0.session) } ?? .loading
      : .loading
    do {
      let fetchedSession = try? await sessions.fetchSession(on: sessionDate)
      let recentCompletedSession = await sessions.recentCompletedSession(before: date)
      let persistedDuration = recentCompletedDurationStore.durationSeconds(studentID: studentID)
      currentOnboarding = try? await onboarding.fetchProfile(studentId: studentID)
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      guard generation == loadGeneration else { return }
      planContext = Self.planContext(from: plan, selectedDate: date)

      guard let day = try await loadDay(from: plan, date: date, studentID: studentID) else {
        guard generation == loadGeneration else { return }
        exerciseReferences = [:]
        state = .rest
        return
      }
      let dayRange = Self.dayRange(containing: day.date)
      let existingLogs = try await logs.fetchLogs(studentID: studentID, in: dayRange)
      let drafts = Self.makeDrafts(for: day, existingLogs: existingLogs)
      let references = try await exerciseReferences(for: day, studentID: studentID)
      guard generation == loadGeneration else { return }
      exerciseReferences = references
      applyFetchedSession(
        fetchedSession,
        isToday: sessionDate == nil,
        issuedStartGeneration: issuedStartGeneration
      )
      lastCompletedDurationSeconds = recentCompletedSession?.durationSeconds ?? persistedDuration
      if let duration = recentCompletedSession?.durationSeconds {
        recentCompletedDurationStore.record(durationSeconds: duration, studentID: studentID)
      }
      state = .loaded(plan: day, drafts: drafts)
    } catch {
      guard generation == loadGeneration else { return }
      if error.isTaskCancellation {
        state = .idle
        return
      }
      state = .error(error.localizedDescription)
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

  /// Persists current draft values and marks the row complete; edits still hit `recordSet`.
  public func commitSet(rowIndex: Int, failed: Bool = false) async {
    await persist(rowIndex: rowIndex, completed: true, failed: failed)
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
    let draft = drafts[rowIndex]
    await persist(rowIndex: rowIndex, completed: draft.completed, failed: draft.failed)
    guard case .loaded(_, let updated) = state, updated.indices.contains(rowIndex) else {
      return nil
    }
    return updated[rowIndex].loggedSetID
  }

  private func persist(rowIndex: Int, completed: Bool, failed: Bool = false) async {
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
      completed: completed,
      failed: failed
    )

    do {
      let previouslyCompleted = drafts[rowIndex].completed
      // The repository returns the canonical (backend-upserted) log: its id
      // is what video linkage and e1RM points must reference (Codex P1).
      let persisted = try await logs.recordSet(log)
      draft.completed = completed
      draft.failed = failed
      draft.loggedSetID = persisted.id
      nextDrafts[rowIndex] = draft
      state = .loaded(plan: plan, drafts: nextDrafts)

      if !nextDrafts.isEmpty && nextDrafts.allSatisfy(\.completed) {
        await completeSessionLocally(at: now())
      }

      // Spec 028 hook: compute e1RM + detect PR only on the false→true edge,
      // so un-checking and re-checking the same set can't farm PR events.
      // Spec 030 rides the same edge for the rest timer.
      if !previouslyCompleted, completed {
        await recordE1RMPoint(for: draft, log: persisted, studentID: studentID)
        startRestTimer(after: draft, drafts: nextDrafts)
      }
    } catch {
      // `persist` flips to `.recording` before awaiting `recordSet`, so a
      // cancelled set-logging task must restore the prior `.loaded` snapshot
      // rather than stranding the UI in `.recording`.
      if error.isTaskCancellation {
        state = .loaded(plan: plan, drafts: drafts)
        return
      }
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
    let seconds =
      draft.prescribed.restSeconds ?? RestTimerPolicy.restSeconds(forRPE: draft.actualRPE)
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
}
