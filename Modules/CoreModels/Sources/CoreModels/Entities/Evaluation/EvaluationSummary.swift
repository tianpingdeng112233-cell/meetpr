import Foundation

/// Coach-authored evaluation summary (spec 033). Field-for-field mirror of
/// the backend student_evaluations wire shape (backend spec 005 §endpoint C).
/// `notify_student` is request-only (booked on the version row server-side)
/// and deliberately absent here.
public struct EvaluationSummary: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let coachId: UUID
  /// NULL when the coach skipped the evaluation period (acquaintance path,
  /// backend spec 005 D10).
  public let evaluationPeriodId: UUID?
  public let overallAssessment: String
  public let trainingPlan: String
  public let wordsToStudent: String?
  public let firstSavedAt: Date
  public let lastUpdatedAt: Date
  public let isActive: Bool

  public init(
    id: UUID,
    studentId: UUID,
    coachId: UUID,
    evaluationPeriodId: UUID? = nil,
    overallAssessment: String,
    trainingPlan: String,
    wordsToStudent: String? = nil,
    firstSavedAt: Date,
    lastUpdatedAt: Date,
    isActive: Bool
  ) {
    self.id = id
    self.studentId = studentId
    self.coachId = coachId
    self.evaluationPeriodId = evaluationPeriodId
    self.overallAssessment = overallAssessment
    self.trainingPlan = trainingPlan
    self.wordsToStudent = wordsToStudent
    self.firstSavedAt = firstSavedAt
    self.lastUpdatedAt = lastUpdatedAt
    self.isActive = isActive
  }
}

extension EvaluationSummary {
  /// First 2 lines / 80 characters of the training plan, for the dashboard
  /// and overview summary cards.
  public var trainingPlanExcerpt: String {
    Self.excerpt(of: trainingPlan)
  }

  /// Same truncation for "给学员的话"; nil when the coach left it blank.
  public var wordsExcerpt: String? {
    wordsToStudent.map { Self.excerpt(of: $0) }
  }

  static func excerpt(of text: String, maxLines: Int = 2, maxCharacters: Int = 80) -> String {
    let allLines = text.split(separator: "\n", omittingEmptySubsequences: true)
    let kept = allLines.prefix(maxLines)
    let joined = kept.joined(separator: "\n")
    if joined.count > maxCharacters {
      return String(joined.prefix(maxCharacters)) + "…"
    }
    return kept.count < allLines.count ? joined + "…" : joined
  }
}
