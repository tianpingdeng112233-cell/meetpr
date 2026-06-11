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

  let studentID: UUID
  @ObservationIgnored private let evaluations: any EvaluationRepository
  @ObservationIgnored private let summaries: any EvaluationSummaryRepository
  @ObservationIgnored let now: @Sendable () -> Date

  init(
    studentID: UUID,
    evaluations: any EvaluationRepository,
    summaries: any EvaluationSummaryRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.studentID = studentID
    self.evaluations = evaluations
    self.summaries = summaries
    self.now = now
  }

  /// Banner shows only for a live (uncompleted) evaluation period.
  var isBannerVisible: Bool {
    guard let evaluation else { return false }
    return evaluation.completedAt == nil
  }

  func load() async {
    // Failures degrade to nil: no banner / "not written" card, both safe.
    evaluation = try? await evaluations.fetchEvaluation(studentID: studentID)
    summary = try? await summaries.fetchSummary(studentID: studentID)
  }

  func reloadSummary() async {
    summary = try? await summaries.fetchSummary(studentID: studentID)
  }

  /// Called by the editor's completion chain so the banner hides without a
  /// refetch.
  func markEvaluationCompleted(_ completed: EvaluationPeriod) {
    evaluation = completed
  }

  /// [完成评估]. The concurrent-complete 409 reads as success: refresh and
  /// hide (spec 033 §6).
  func complete() async -> Bool {
    guard let evaluation, evaluation.completedAt == nil else { return true }
    completeError = nil
    do {
      self.evaluation = try await evaluations.completeEvaluation(id: evaluation.id)
      return true
    } catch EvaluationError.alreadyCompleted {
      self.evaluation = try? await evaluations.fetchEvaluation(studentID: studentID)
      return true
    } catch {
      completeError = "完成评估失败,请稍后重试"
      return false
    }
  }

  /// "评估期 · 还剩 4 天 13 小时" / "已超期 2 天,请尽快交付总结".
  func statusText(now: Date) -> String {
    guard let evaluation else { return "" }
    if let overdueBy = evaluation.overdueBy(now: now) {
      let amount = overdueBy.days > 0 ? "\(overdueBy.days) 天" : "\(overdueBy.hours) 小时"
      return "已超期 \(amount),请尽快交付总结"
    }
    if let remaining = evaluation.remaining(now: now) {
      return "评估期 · 还剩 \(remaining.days) 天 \(remaining.hours) 小时"
    }
    return "评估期"
  }

  func isOverdue(now: Date) -> Bool {
    evaluation?.isOverdue(now: now) ?? false
  }

  func progress(now: Date) -> Double {
    evaluation?.progressFraction(now: now) ?? 0
  }
}
