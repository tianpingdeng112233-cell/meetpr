import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Student evaluation-period page state (spec 033 §11): countdown, the
/// latest coach messages (feedback reuse), and the adaptation-week training
/// entry. Completion is discovered on foreground/appear refresh — no
/// background polling (V0.1b has no push).
@Observable
@MainActor
public final class EvaluationPeriodViewModel {
  public enum State: Equatable, Sendable {
    case loading
    case active(EvaluationPeriod)
    case failed
  }

  public private(set) var state: State = .loading
  /// Published adaptation plan; during a live evaluation any published plan
  /// is the adaptation week (the backend gate blocks regular plans).
  public private(set) var adaptationPlan: StudentPlanView?
  /// Latest 3 coach messages, newest first.
  public private(set) var latestMessages: [CoachFeedback] = []

  public let studentID: UUID
  @ObservationIgnored private let evaluations: any EvaluationRepository
  @ObservationIgnored private let plans: any StudentPlanRepository
  @ObservationIgnored private let feedback: any StudentFeedbackRepository
  /// Fired when the evaluation turned out completed (or vanished) — the
  /// BindGate converges to the 5-tab UI.
  @ObservationIgnored private let onCompleted: @MainActor () async -> Void

  public init(
    studentID: UUID,
    evaluations: any EvaluationRepository,
    plans: any StudentPlanRepository,
    feedback: any StudentFeedbackRepository,
    onCompleted: @escaping @MainActor () async -> Void = {}
  ) {
    self.studentID = studentID
    self.evaluations = evaluations
    self.plans = plans
    self.feedback = feedback
    self.onCompleted = onCompleted
  }

  public func refresh() async {
    do {
      guard let evaluation = try await evaluations.fetchMyEvaluation(),
        evaluation.completedAt == nil
      else {
        await onCompleted()
        return
      }
      state = .active(evaluation)
    } catch {
      if state == .loading { state = .failed }
      return
    }

    // Secondary content degrades quietly — the countdown is the page.
    adaptationPlan = try? await plans.fetchCurrentPlan(studentID: studentID)
    let inbox = (try? await feedback.fetchInbox(studentID: studentID)) ?? []
    latestMessages = Array(inbox.sorted { $0.postedAt > $1.postedAt }.prefix(3))
  }

  /// "评估期还剩: 4 天 13 小时"; overdue shows the neutral closing copy —
  /// never a negative hint (wiki §4.4 决议 1.5).
  public func countdownText(now: Date) -> String {
    guard case .active(let evaluation) = state else { return "" }
    if let remaining = evaluation.remaining(now: now) {
      return "评估期还剩: \(remaining.days) 天 \(remaining.hours) 小时"
    }
    return "评估即将完成"
  }

  public func progress(now: Date) -> Double {
    guard case .active(let evaluation) = state else { return 0 }
    return evaluation.progressFraction(now: now)
  }

  public var hasAdaptationTraining: Bool {
    guard let adaptationPlan else { return false }
    return adaptationPlan.days.contains { !$0.exercises.isEmpty }
  }
}
