import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Evaluation summary editor (spec 033 §8). First-save mode offers
/// 保存草稿 / 完成并通知学员; edit mode offers 保存 + an opt-in notify
/// checkbox (D4). The completion chain is PUT-first so the summary text
/// never gets lost when completing the evaluation fails (D3).
@Observable
@MainActor
final class EvaluationSummaryEditorViewModel {
  enum LoadState: Equatable, Sendable {
    case loading
    case ready
    case failed
  }

  static let maxFieldLength = 10_000

  var state: LoadState = .loading
  var overallAssessment = ""
  var trainingPlanText = ""
  var wordsToStudent = ""
  /// Edit-mode "同时通知学员" checkbox — default off (D4).
  var notifyOnSave = false
  /// Degraded-chain banner (summary saved, completing failed).
  var noticeMessage: String?
  /// Drives the soft-recommendation alert (spec 033 §9).
  var showSoftRecommendation = false
  /// Toast for a profile fetch miss on [立即排].
  var prefillNotice: String?
  private(set) var isSaving = false
  private(set) var existingSummary: EvaluationSummary?
  private(set) var lastSavedAt: Date?

  let student: CoachStudentSummary
  @ObservationIgnored private let summaries: any EvaluationSummaryRepository
  @ObservationIgnored private let evaluations: any EvaluationRepository
  @ObservationIgnored private let profiles: any OnboardingProfileReading
  /// The live evaluation period when entering (nil for skip-evaluation
  /// students); the chain re-checks completion state at run time.
  @ObservationIgnored private var evaluation: EvaluationPeriod?
  @ObservationIgnored private let onEvaluationCompleted: @MainActor (EvaluationPeriod) -> Void

  init(
    student: CoachStudentSummary,
    evaluation: EvaluationPeriod?,
    summaries: any EvaluationSummaryRepository,
    evaluations: any EvaluationRepository,
    profiles: any OnboardingProfileReading,
    onEvaluationCompleted: @escaping @MainActor (EvaluationPeriod) -> Void = { _ in }
  ) {
    self.student = student
    self.evaluation = evaluation
    self.summaries = summaries
    self.evaluations = evaluations
    self.profiles = profiles
    self.onEvaluationCompleted = onEvaluationCompleted
  }

  /// Edit mode once a summary exists server-side (wiki §5.4).
  var isEditMode: Bool { existingSummary != nil }

  /// Both required fields non-blank after trimming (zod min(1) alignment).
  var canSave: Bool {
    !trimmed(overallAssessment).isEmpty && !trimmed(trainingPlanText).isEmpty
  }

  func load() async {
    state = .loading
    do {
      if let summary = try await summaries.fetchSummary(studentID: student.id) {
        existingSummary = summary
        overallAssessment = summary.overallAssessment
        trainingPlanText = summary.trainingPlan
        wordsToStudent = summary.wordsToStudent ?? ""
      }
      state = .ready
    } catch {
      state = .failed
    }
  }

  /// 保存草稿 (first save, notify false) / 保存 (edit mode, notify =
  /// checkbox). Returns true on success.
  func save() async -> Bool {
    let notify = isEditMode ? notifyOnSave : false
    return await put(notify: notify)
  }

  /// 完成并通知学员 — ① PUT(notify) → ② complete live evaluation (409
  /// ignored; other failures degrade with the summary kept) → ③ soft
  /// recommendation (D3). Skip-evaluation students run ① + ③ only.
  func completeAndNotify() async -> Bool {
    guard await put(notify: true) else { return false }

    if let evaluation, evaluation.completedAt == nil {
      do {
        let completed = try await evaluations.completeEvaluation(id: evaluation.id)
        self.evaluation = completed
        onEvaluationCompleted(completed)
      } catch EvaluationError.alreadyCompleted {
        // Concurrent complete — converged, proceed.
        if let refreshed = try? await evaluations.fetchEvaluation(studentID: student.id) {
          self.evaluation = refreshed
          onEvaluationCompleted(refreshed)
        }
      } catch {
        // Summary is saved (PUT-first); the banner stays for a retry.
        noticeMessage = "总结已保存,但完成评估失败,请在学员详情页重试"
        return false
      }
    }

    showSoftRecommendation = true
    return true
  }

  /// [立即排] profile fetch; nil (missing / failed) still enters planning
  /// without prefill (spec 033 §9).
  func fetchPrefillProfile() async -> OnboardingProfile? {
    if let profile = try? await profiles.fetchProfile(studentId: student.id) {
      return profile
    }
    prefillNotice = "学员资料未读到,手动填写"
    return nil
  }

  private func put(notify: Bool) async -> Bool {
    guard canSave, !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }
    noticeMessage = nil
    do {
      let words = trimmed(wordsToStudent)
      let summary = try await summaries.putSummary(
        studentID: student.id,
        overallAssessment: trimmed(overallAssessment),
        trainingPlan: trimmed(trainingPlanText),
        wordsToStudent: words.isEmpty ? nil : words,
        notifyStudent: notify
      )
      existingSummary = summary
      lastSavedAt = summary.lastUpdatedAt
      return true
    } catch {
      noticeMessage = "保存失败,请重试"
      return false
    }
  }

  private func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
