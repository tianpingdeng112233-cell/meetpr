// swiftlint:disable file_length
import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
// swiftlint:disable:next type_body_length
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
  public private(set) var pendingPRBanner: PRBreakthroughEvent?
  public private(set) var restTimer: RestTimerState?
  public private(set) var showsRestTimerExplanation = false
  public private(set) var planContext: TodayWorkoutPlanContext?
  public private(set) var exerciseReferences: [UUID: ExerciseReference] = [:]
  /// Latest logged weight per catalog exercise (variation/accessory fill).
  public private(set) var lastWeightByExercise: [UUID: Decimal] = [:]
  public private(set) var actionErrorMessage: String?
  public private(set) var onboardingProfile: OnboardingProfile?

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let e1rmRepo: any E1RMRepository
  private let onboarding: (any OnboardingProfileReading)?
  private let restTimerSettings: any StudentRestTimerSettingsStoring
  private let calendar: Calendar
  private let now: @Sendable () -> Date
  private var currentStudentID: UUID?
  private var loadGeneration = 0
  private var pendingPersist: Task<Bool, Never>?

  public init(
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository = InMemoryE1RMRepository(),
    onboarding: (any OnboardingProfileReading)? = nil,
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    calendar: Calendar = .current,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.plans = plans
    self.logs = logs
    self.e1rmRepo = e1rm
    self.onboarding = onboarding
    self.restTimerSettings = restTimerSettings
    self.calendar = calendar
    self.now = now
  }

  public func load(date: Date, studentID: UUID) async {
    currentStudentID = studentID
    loadGeneration += 1
    let generation = loadGeneration
    state = .loading
    do {
      onboardingProfile = try? await onboarding?.fetchProfile(studentId: studentID)
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      guard isCurrentLoad(generation) else { return }
      planContext = Self.planContext(from: plan, selectedDate: date, calendar: calendar)

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
      // Best-effort: the last-weight fill must never fail the day load.
      let historyLogs =
        (try? await logs.fetchLogs(
          studentID: studentID, in: Self.lastWeightHistoryRange(before: day.date))) ?? []
      guard isCurrentLoad(generation) else { return }
      exerciseReferences = references
      lastWeightByExercise = Self.lastWeights(
        from: historyLogs,
        planExerciseToExercise: Self.planExerciseMap(plan: plan, day: day)
      )
      state = .loaded(plan: day, drafts: drafts)
    } catch {
      guard isCurrentLoad(generation) else { return }
      state = error.isTaskCancellation ? .idle : .error(Self.loadErrorMessage(for: error))
    }
  }

  private func loadDay(
    from plan: StudentPlanView?,
    date: Date,
    studentID: UUID
  ) async throws -> StudentPlanDay? {
    if let day = plan?.days.first(where: {
      PlanCalendarDayIdentity.matches(
        planDate: $0.date,
        selectedDate: date,
        selectedCalendar: calendar
      )
    }) {
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
    _ = await persist(rowIndex: rowIndex, completed: !drafts[rowIndex].completed)
  }

  @discardableResult
  public func commitSet(rowIndex: Int, failed: Bool = false) async -> Bool {
    await persist(rowIndex: rowIndex, completed: true, failed: failed)
  }

  public func ensureLoggedSetID(rowIndex: Int) async -> UUID? {
    guard case .loaded(_, let drafts) = state, drafts.indices.contains(rowIndex) else {
      return nil
    }
    if let loggedSetID = drafts[rowIndex].loggedSetID {
      return loggedSetID
    }
    let draft = drafts[rowIndex]
    guard await persist(rowIndex: rowIndex, completed: draft.completed, failed: draft.failed) else {
      return nil
    }
    // currentDrafts, not `case .loaded`: a chained follow-up persist may have
    // already flipped state to .recording by the time this continuation runs.
    guard let updated = currentDrafts, updated.indices.contains(rowIndex) else {
      return nil
    }
    return updated[rowIndex].loggedSetID
  }

  public func clearActionError() {
    actionErrorMessage = nil
  }

  private func performPersist(
    rowIndex: Int, completed: Bool, failed: Bool, generation: Int
  ) async -> Bool {
    guard let studentID = currentStudentID else {
      actionErrorMessage = "无法确认当前学员，请重新进入训练页后重试。"
      return false
    }
    guard case .loaded(let plan, let drafts) = state, drafts.indices.contains(rowIndex) else {
      return false
    }
    actionErrorMessage = nil
    let nextDrafts = drafts
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
      let persisted = try await logs.recordSet(log)
      // The page moved to another day while recordSet was in flight: the log
      // is safely on the server and the reload owns state — don't merge a
      // stale day's flags into the new day's drafts.
      guard isCurrentLoad(generation) else { return true }
      // Merge into the latest drafts: field syncs may have landed while
      // recordSet was in flight; restoring the captured array would drop them.
      var latestDrafts = currentDrafts ?? nextDrafts
      draft = latestDrafts.indices.contains(rowIndex) ? latestDrafts[rowIndex] : draft
      draft.completed = completed
      draft.failed = failed
      draft.loggedSetID = persisted.id
      if latestDrafts.indices.contains(rowIndex) {
        latestDrafts[rowIndex] = draft
      }
      state = .loaded(plan: plan, drafts: latestDrafts)

      if !previouslyCompleted, completed {
        await recordE1RMPoint(for: draft, log: persisted, studentID: studentID)
        startRestTimer(after: draft, drafts: latestDrafts)
      }
      return true
    } catch {
      if isCurrentLoad(generation) {
        state = .loaded(plan: plan, drafts: currentDrafts ?? drafts)
      }
      if !error.isTaskCancellation {
        actionErrorMessage = Self.recordingErrorMessage(for: error)
      }
      return false
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

  public func acknowledgeRestTimerExplanation() {
    guard let currentStudentID else { return }
    restTimerSettings.markExplanationAcknowledged(for: currentStudentID)
    showsRestTimerExplanation = false
  }

  private func startRestTimer(after draft: SetRowDraft, drafts: [SetRowDraft]) {
    guard !drafts.allSatisfy(\.completed) else {
      restTimer = nil
      return
    }
    let seconds =
      draft.prescribed.restSeconds
      ?? currentStudentID.flatMap { restTimerSettings.preference(for: $0).fixedSeconds }
      ?? RestTimerPolicy.restSeconds(forRPE: draft.actualRPE)
    restTimer = RestTimerState(
      endsAt: now().addingTimeInterval(TimeInterval(seconds)), totalSeconds: seconds)
    if let currentStudentID,
      !restTimerSettings.hasAcknowledgedExplanation(for: currentStudentID)
    {
      showsRestTimerExplanation = true
    }
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
    selectedDate: Date,
    calendar: Calendar
  ) -> TodayWorkoutPlanContext? {
    guard let plan else { return nil }
    return TodayWorkoutPlanContext(
      planKind: plan.planKind,
      weekIndex: weekIndex(
        for: selectedDate,
        startDate: plan.startDate,
        fallback: plan.weekIndex,
        calendar: calendar
      ),
      startDate: plan.startDate
    )
  }

  private static func weekIndex(
    for date: Date,
    startDate: Date,
    fallback: Int,
    calendar: Calendar
  ) -> Int {
    guard
      let elapsedDays = PlanCalendarDayIdentity.dayOffset(
        fromPlanDate: startDate,
        toSelectedDate: date,
        selectedCalendar: calendar
      )
    else {
      return fallback
    }
    return max(1, elapsedDays / 7 + 1)
  }

  // Internal + nonisolated (not private): the DraftBuilding extension derives
  // the last-weight lookback window from it in a separate file, off-actor.
  nonisolated static func dayRange(containing date: Date) -> ClosedRange<Date> {
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
    let familyByExercise = Dictionary(
      day.exercises.map {
        (
          $0.exercise.id,
          resolveCompetitionFamily(exercise: $0.exercise, onboarding: onboardingProfile)
        )
      },
      uniquingKeysWith: { first, _ in first }
    )
    let exerciseIDs = Set(day.exercises.map(\.exercise.id))
    let e1rmRepo = self.e1rmRepo
    return try await withThrowingTaskGroup(of: (UUID, ExerciseReference?).self) { group in
      for exerciseID in exerciseIDs {
        let family = familyByExercise[exerciseID].flatMap { $0 }
        group.addTask {
          let points = try await e1rmRepo.fetchHistory(studentId: studentID, exerciseId: exerciseID)
          let selected = lastAndBest(
            from: E1RMSeries.trustedEligibleRaw(points: points, family: family)
          )
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

  func recordE1RMPoint(
    for draft: SetRowDraft,
    log: StudentSetLog,
    studentID: UUID
  ) async {
    let recorder = E1RMRecorder(e1rm: e1rmRepo, now: now)
    let event = await recorder.record(
      E1RMRecorder.Input(
        studentID: studentID,
        exerciseID: draft.exerciseID,
        family: exerciseFamily(planExerciseID: draft.planExerciseID),
        setLogID: log.id,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: draft.actualRPE,
        completed: log.completed,
        failed: log.failed
      )
    )
    if let event {
      pendingPRBanner = event
    }
  }

  private func exerciseFamily(planExerciseID: UUID) -> LiftFamily? {
    let day: StudentPlanDay?
    switch state {
    case .loaded(let plan, _), .recording(let plan, _, _):
      day = plan
    default:
      day = nil
    }
    guard let exercise = day?.exercises.first(where: { $0.id == planExerciseID })?.exercise
    else { return nil }
    return resolveCompetitionFamily(exercise: exercise, onboarding: onboardingProfile)
  }
}

// MARK: - Persist serialization
extension TodayWorkoutViewModel {
  /// The entry sheet stays alive across persists (single render branch), so a
  /// video attach and 完成本组 can overlap — chain persists so completions
  /// apply in submission order instead of racing.
  fileprivate func persist(rowIndex: Int, completed: Bool, failed: Bool = false) async -> Bool {
    let previous = pendingPersist
    // Queued work is only valid for the day it was submitted against: a day
    // switch reloads drafts and rowIndex would address the wrong set.
    let generation = loadGeneration
    let task = Task { [weak self] in
      _ = await previous?.value
      guard let self, self.isCurrentLoad(generation) else { return false }
      return await self.performPersist(
        rowIndex: rowIndex, completed: completed, failed: failed, generation: generation)
    }
    pendingPersist = task
    return await task.value
  }

  var currentDrafts: [SetRowDraft]? {
    switch state {
    case .loaded(_, let drafts), .recording(_, let drafts, _): drafts
    default: nil
    }
  }
}
