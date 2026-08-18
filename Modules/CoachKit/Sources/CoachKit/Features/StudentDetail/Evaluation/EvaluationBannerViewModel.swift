import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Evaluation-period state for the student detail page (spec 033 §6): the
/// countdown banner plus the overview's summary card data. Time strings are
/// always computed from wire timestamps + the injected now.
@Observable
@MainActor
final class EvaluationBannerViewModel {
  private(set) var evaluation: EvaluationPeriod?
  private(set) var summary: EvaluationSummary?
  /// Recovery banner for a failed [完成评估].
  var completeError: String?
  /// True when the evaluation/summary fetch failed on transport: the page
  /// can't tell "no evaluation" from "couldn't read it", so it surfaces a
  /// retry strip instead of silently hiding a live banner (Codex review P2).
  private(set) var loadFailed = false

  let studentID: UUID
  @ObservationIgnored private let evaluations: any EvaluationRepository
  @ObservationIgnored private let summaries: any EvaluationSummaryRepository
  @ObservationIgnored let now: @Sendable () -> Date
  /// Fired whenever the evaluation reaches completed via this page (banner
  /// [完成评估] or the editor chain), so the roster can drop its stale
  /// "评估中" badge (Codex review P1).
  @ObservationIgnored private let onCompleted: (@MainActor () -> Void)?

  init(
    studentID: UUID,
    evaluations: any EvaluationRepository,
    summaries: any EvaluationSummaryRepository,
    now: @escaping @Sendable () -> Date = { Date() },
    onCompleted: (@MainActor () -> Void)? = nil
  ) {
    self.studentID = studentID
    self.evaluations = evaluations
    self.summaries = summaries
    self.now = now
    self.onCompleted = onCompleted
  }

  /// Banner shows only for a live (uncompleted) evaluation period.
  var isBannerVisible: Bool {
    guard let evaluation else { return false }
    return evaluation.completedAt == nil
  }

  func load() async {
    // 404s arrive as nil from the repository (no banner / "not written"
    // card, both real states); only transport failures set loadFailed.
    do {
      evaluation = try await evaluations.fetchEvaluation(studentID: studentID)
      summary = try await summaries.fetchSummary(studentID: studentID)
      loadFailed = false
    } catch {
      loadFailed = true
    }
  }

  func reloadSummary() async {
    do {
      summary = try await summaries.fetchSummary(studentID: studentID)
    } catch {
      // Keep the last-known summary; the overview card tolerates staleness.
    }
  }

  /// Called by the editor's completion chain so the banner hides without a
  /// refetch.
  func markEvaluationCompleted(_ completed: EvaluationPeriod) {
    evaluation = completed
    onCompleted?()
  }

  /// [完成评估]. The concurrent-complete 409 reads as success: refresh and
  /// hide (spec 033 §6).
  func complete() async -> Bool {
    guard let evaluation, evaluation.completedAt == nil else { return true }
    completeError = nil
    do {
      self.evaluation = try await evaluations.completeEvaluation(id: evaluation.id)
      onCompleted?()
      return true
    } catch EvaluationError.alreadyCompleted {
      self.evaluation = try? await evaluations.fetchEvaluation(studentID: studentID)
      onCompleted?()
      return true
    } catch {
      completeError = CoachStudentDetailStrings.text("coach.evaluation.error.complete")
      return false
    }
  }

  /// "评估期 · 还剩 4 天 13 小时" / "已超期 2 天,请尽快交付总结".
  func statusText(now: Date) -> String {
    guard let evaluation else { return "" }
    if let overdueBy = evaluation.overdueBy(now: now) {
      let amount =
        overdueBy.days > 0
        ? CoachLocalization.localized("coach.evaluation.duration.days \(overdueBy.days)")
        : CoachLocalization.localized("coach.evaluation.duration.hours \(overdueBy.hours)")
      return CoachStudentDetailStrings.replacing(
        "coach.evaluation.overdue", ["duration": amount])
    }
    if let remaining = evaluation.remaining(now: now) {
      return CoachLocalization.localized(
        "coach.evaluation.remaining \(remaining.days) \(remaining.hours)")
    }
    return CoachStudentDetailStrings.text("coach.evaluation.title")
  }

  func isOverdue(now: Date) -> Bool {
    evaluation?.isOverdue(now: now) ?? false
  }

  func progress(now: Date) -> Double {
    evaluation?.progressFraction(now: now) ?? 0
  }
}
