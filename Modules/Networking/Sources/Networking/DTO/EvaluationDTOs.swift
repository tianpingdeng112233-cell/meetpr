import CoreModels
import Foundation

// Wire DTOs for the evaluation period + summary endpoints (spec 033; field
// names verbatim from backend spec 005 §endpoint C — snake_case conversion
// via MeetPRCodec).

public struct EvaluationPeriodDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let studentId: UUID
  public let coachId: UUID
  public let bindRequestId: UUID
  public let startedAt: Date
  public let expectedEndAt: Date
  public let completedAt: Date?
  public let completionType: String?
  public let inProgress: Bool
  public let overdue: Bool

  public init(
    id: UUID,
    studentId: UUID,
    coachId: UUID,
    bindRequestId: UUID,
    startedAt: Date,
    expectedEndAt: Date,
    completedAt: Date?,
    completionType: String?,
    inProgress: Bool,
    overdue: Bool
  ) {
    self.id = id
    self.studentId = studentId
    self.coachId = coachId
    self.bindRequestId = bindRequestId
    self.startedAt = startedAt
    self.expectedEndAt = expectedEndAt
    self.completedAt = completedAt
    self.completionType = completionType
    self.inProgress = inProgress
    self.overdue = overdue
  }

  public func toDomain() -> EvaluationPeriod {
    EvaluationPeriod(
      id: id,
      studentId: studentId,
      coachId: coachId,
      bindRequestId: bindRequestId,
      startedAt: startedAt,
      expectedEndAt: expectedEndAt,
      completedAt: completedAt,
      completionType: completionType,
      inProgress: inProgress,
      overdue: overdue
    )
  }
}

public struct EvaluationSummaryDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let studentId: UUID
  public let coachId: UUID
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
    evaluationPeriodId: UUID?,
    overallAssessment: String,
    trainingPlan: String,
    wordsToStudent: String?,
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

  public func toDomain() -> EvaluationSummary {
    EvaluationSummary(
      id: id,
      studentId: studentId,
      coachId: coachId,
      evaluationPeriodId: evaluationPeriodId,
      overallAssessment: overallAssessment,
      trainingPlan: trainingPlan,
      wordsToStudent: wordsToStudent,
      firstSavedAt: firstSavedAt,
      lastUpdatedAt: lastUpdatedAt,
      isActive: isActive
    )
  }
}

/// PUT /coach/students/:id/evaluation-summary body. zod `.strict()` with
/// `words_to_student` nullable optional: omit the key entirely when blank
/// (custom encode), never send an empty string (zod min(1)).
public struct PutEvaluationSummaryRequestDTO: Encodable, Equatable, Sendable {
  public let overallAssessment: String
  public let trainingPlan: String
  public let wordsToStudent: String?
  public let notifyStudent: Bool

  public init(
    overallAssessment: String,
    trainingPlan: String,
    wordsToStudent: String?,
    notifyStudent: Bool
  ) {
    self.overallAssessment = overallAssessment
    self.trainingPlan = trainingPlan
    self.wordsToStudent = wordsToStudent
    self.notifyStudent = notifyStudent
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(overallAssessment, forKey: .overallAssessment)
    try container.encode(trainingPlan, forKey: .trainingPlan)
    try container.encodeIfPresent(wordsToStudent, forKey: .wordsToStudent)
    try container.encode(notifyStudent, forKey: .notifyStudent)
  }

  private enum CodingKeys: String, CodingKey {
    case overallAssessment, trainingPlan, wordsToStudent, notifyStudent
  }
}
