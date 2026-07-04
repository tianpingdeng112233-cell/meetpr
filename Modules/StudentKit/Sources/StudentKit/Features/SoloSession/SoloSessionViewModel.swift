import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Drives a solo (adhoc) training session: 日即会话, sets keyed on
/// (exercise, session day, set index) per backend spec 010. Mirrors
/// TodayWorkoutViewModel's draft/commit shape without any plan coupling.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Observable
public final class SoloSessionViewModel {
  public private(set) var drafts: [SoloSetDraft] = []
  /// The locked training day (YYYY-MM-DD, device-local): whatever day it was
  /// when the session loaded — a set committed at 00:10 still belongs to the
  /// evening you started lifting.
  public private(set) var sessionDate: String
  public private(set) var suggestions: SoloExerciseSuggestions = .empty
  /// Exercises + set counts from the last day trained before today, for the
  /// 「重复上次」 card.
  public private(set) var lastSessionDate: String?
  public private(set) var lastSessionDrafts: [SoloSetDraft] = []
  public private(set) var unsyncedCount = 0
  public private(set) var pendingPRBanner: PRBreakthroughEvent?

  @ObservationIgnored private let studentID: UUID
  @ObservationIgnored private let logs: any StudentTrainingLogRepository
  @ObservationIgnored private let e1rmRepo: any E1RMRepository
  @ObservationIgnored private let exerciseNames: [UUID: String]
  @ObservationIgnored private let exerciseFamilies: [UUID: LiftFamily]
  @ObservationIgnored private let pendingCount: @Sendable (UUID) async -> Int
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let calendar: Calendar
  /// Next server set_index per exercise for the locked session day.
  @ObservationIgnored private var nextSetIndex: [UUID: Int] = [:]

  public init(
    studentID: UUID,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository,
    catalog: [Exercise],
    pendingCount: @escaping @Sendable (UUID) async -> Int = { _ in 0 },
    now: @escaping () -> Date = Date.init,
    calendar: Calendar = .current
  ) {
    self.studentID = studentID
    self.logs = logs
    self.e1rmRepo = e1rm
    self.exerciseNames = Dictionary(
      catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    self.exerciseFamilies = Dictionary(
      catalog.compactMap { exercise in
        exercise.mainLiftFamily.map { (exercise.id, $0) }
      },
      uniquingKeysWith: { first, _ in first })
    self.pendingCount = pendingCount
    self.now = now
    self.calendar = calendar
    self.sessionDate = Self.dayString(now(), calendar: calendar)
  }

  /// Loads today's already-committed sets (继续训练), the previous session
  /// for 「重复上次」, and picker suggestions. Locks the session day.
  public func load() async {
    sessionDate = Self.dayString(now(), calendar: calendar)
    let today = now()
    guard let windowStart = calendar.date(byAdding: .day, value: -90, to: today) else { return }

    let history =
      (try? await logs.fetchLogs(studentID: studentID, in: windowStart...today, scope: .all)) ?? []

    let todayRows =
      history
      .filter { ($0.loggedDate ?? "") == sessionDate }
      .sorted(by: Self.adhocOrder)
    drafts = todayRows.compactMap(draft(from:))
    nextSetIndex = todayRows.reduce(into: [:]) { acc, log in
      guard let exerciseID = log.exerciseID else { return }
      acc[exerciseID] = max(acc[exerciseID] ?? 0, log.setIndex + 1)
    }

    let previousDays = history.compactMap(\.loggedDate).filter { $0 < sessionDate }
    if let lastDay = previousDays.max() {
      lastSessionDate = lastDay
      lastSessionDrafts =
        history
        .filter { $0.loggedDate == lastDay }
        .sorted(by: Self.adhocOrder)
        .compactMap(uncommittedDraft(from:))
    } else {
      lastSessionDate = nil
      lastSessionDrafts = []
    }

    suggestions = Self.suggestions(from: history)
    unsyncedCount = await pendingCount(studentID)
  }

  public func addExercise(_ exerciseID: UUID) {
    drafts.append(
      SoloSetDraft(exerciseID: exerciseID, exerciseName: name(of: exerciseID)))
  }

  /// Adds the next set for an exercise, prefilled from its latest row —
  /// the "same weight, next set" gym default.
  public func addSet(for exerciseID: UUID) {
    let template = drafts.last { $0.exerciseID == exerciseID }
    drafts.append(
      SoloSetDraft(
        exerciseID: exerciseID,
        exerciseName: name(of: exerciseID),
        weightKg: template?.weightKg,
        reps: template?.reps,
        rpe: template?.rpe
      ))
  }

  /// Prefills the whole session from the last day trained (「重复上次」).
  /// Weights/reps carry over; RPE is the day's own judgement and stays empty.
  public func repeatLastSession() {
    guard drafts.allSatisfy({ $0.completed == false && $0.weightKg == nil }) || drafts.isEmpty
    else { return }
    drafts = lastSessionDrafts
  }

  public func updateDraft(
    id: UUID, weightKg: Decimal? = nil, reps: Int? = nil, rpe: Decimal? = nil
  ) {
    guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
    if let weightKg { drafts[index].weightKg = weightKg }
    if let reps { drafts[index].reps = reps }
    if let rpe { drafts[index].rpe = rpe }
  }

  public func removeDraft(id: UUID) {
    drafts.removeAll { $0.id == id && $0.completed == false }
  }

  /// Commits one row: assigns the next set_index for its exercise on the
  /// locked session day and records it (offline parking handled by the
  /// queued repository underneath).
  public func commit(id: UUID, failed: Bool = false) async {
    guard let index = drafts.firstIndex(where: { $0.id == id }),
      drafts[index].completed == false,
      let weightKg = drafts[index].weightKg,
      let reps = drafts[index].reps
    else { return }

    let draft = drafts[index]
    let setIndex = nextSetIndex[draft.exerciseID] ?? 0
    let log = StudentSetLog(
      id: UUID(),
      studentID: studentID,
      planExerciseID: nil,
      exerciseID: draft.exerciseID,
      loggedDate: sessionDate,
      adhoc: true,
      setIndex: setIndex,
      loggedAt: now(),
      weightKg: weightKg,
      reps: reps,
      rpe: draft.rpe,
      completed: true,
      failed: failed
    )

    do {
      let persisted = try await logs.recordAdhocSet(log)
      drafts[index].completed = true
      drafts[index].failed = failed
      drafts[index].committedSetIndex = setIndex
      nextSetIndex[draft.exerciseID] = setIndex + 1
      await recordE1RMPoint(for: drafts[index], log: persisted)
      unsyncedCount = await pendingCount(studentID)
    } catch {
      // Non-queueable failure (validation): leave the row editable; the UI
      // surfaces retry affordances.
    }
  }

  public func acknowledgePendingPR() async {
    guard let banner = pendingPRBanner else { return }
    try? await e1rmRepo.acknowledgePR(eventId: banner.id)
    pendingPRBanner = nil
  }

  // MARK: - Derivations

  public func exerciseName(for exerciseID: UUID) -> String? {
    exerciseNames[exerciseID]
  }

  private func name(of exerciseID: UUID) -> String {
    exerciseNames[exerciseID] ?? "动作"
  }

  private func draft(from log: StudentSetLog) -> SoloSetDraft? {
    guard let exerciseID = log.exerciseID else { return nil }
    return SoloSetDraft(
      id: log.id,
      exerciseID: exerciseID,
      exerciseName: name(of: exerciseID),
      weightKg: log.weightKg,
      reps: log.reps,
      rpe: log.rpe,
      completed: true,
      failed: log.failed,
      committedSetIndex: log.setIndex
    )
  }

  private func uncommittedDraft(from log: StudentSetLog) -> SoloSetDraft? {
    guard let exerciseID = log.exerciseID else { return nil }
    return SoloSetDraft(
      exerciseID: exerciseID,
      exerciseName: name(of: exerciseID),
      weightKg: log.weightKg,
      reps: log.reps,
      rpe: nil
    )
  }

  static func suggestions(from history: [StudentSetLog]) -> SoloExerciseSuggestions {
    let dated = history.compactMap { log -> (UUID, String)? in
      guard let exerciseID = log.exerciseID, let day = log.loggedDate else { return nil }
      return (exerciseID, day)
    }
    var latestDay: [UUID: String] = [:]
    var counts: [UUID: Int] = [:]
    for (exerciseID, day) in dated {
      latestDay[exerciseID] = max(latestDay[exerciseID] ?? "", day)
      counts[exerciseID, default: 0] += 1
    }
    let recent = latestDay.sorted { $0.value > $1.value }.map(\.key)
    let frequent = counts.sorted { ($0.value, $1.key.uuidString) > ($1.value, $0.key.uuidString) }
      .map(\.key)
    return SoloExerciseSuggestions(recent: recent, frequent: frequent)
  }

  static func adhocOrder(_ lhs: StudentSetLog, _ rhs: StudentSetLog) -> Bool {
    let lhsKey = (lhs.exerciseID?.uuidString ?? "", lhs.setIndex)
    let rhsKey = (rhs.exerciseID?.uuidString ?? "", rhs.setIndex)
    return lhsKey < rhsKey
  }

  static func dayString(_ date: Date, calendar: Calendar) -> String {
    var formatStyle = Date.ISO8601FormatStyle(timeZone: calendar.timeZone)
      .year().month().day()
    formatStyle.timeZone = calendar.timeZone
    return date.formatted(formatStyle)
  }

  /// Shared pipeline (spec 050 §3): eligibility gate + noise-banded PR.
  private func recordE1RMPoint(for draft: SoloSetDraft, log: StudentSetLog) async {
    let capturedNow = now()
    let recorder = E1RMRecorder(e1rm: e1rmRepo, now: { capturedNow })
    let event = await recorder.record(
      E1RMRecorder.Input(
        studentID: studentID,
        exerciseID: draft.exerciseID,
        family: exerciseFamilies[draft.exerciseID],
        setLogID: log.id,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: draft.rpe,
        failed: log.failed
      ))
    if let event {
      pendingPRBanner = event
    }
  }
}
