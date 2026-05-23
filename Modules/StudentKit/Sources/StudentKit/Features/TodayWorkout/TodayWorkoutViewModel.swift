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
      self.exerciseName = exerciseName
      self.prescribed = prescribed
      self.actualWeight = actualWeight
      self.actualReps = actualReps
      self.actualRPE = actualRPE
      self.completed = completed
      self.loggedSetID = loggedSetID
    }
  }

  public private(set) var state: State = .idle

  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let now: @Sendable () -> Date
  private var currentStudentID: UUID?

  public init(
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.plans = plans
    self.logs = logs
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
      try await logs.recordSet(log)
      draft.completed = completed
      draft.loggedSetID = log.id
      nextDrafts[rowIndex] = draft
      state = .loaded(plan: plan, drafts: nextDrafts)
    } catch {
      state = .error(error.localizedDescription)
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
