import CoreModels
import Foundation

public enum SessionReviewRepositoryError: Error, Equatable {
  /// Submitting an empty/whitespace-only feeling — the UI should disable
  /// the action, this is the backstop.
  case emptyFeeling
}

/// Writes and reads back the student's own session reviews (spec 051).
public protocol SessionReviewRepository: Sendable {
  /// Upsert by (student, training day): rewriting the same day overwrites.
  @discardableResult
  func submitReview(
    studentID: UUID,
    reviewDate: String,
    feeling: String,
    sessionRPE: Decimal?
  ) async throws -> SessionReview
  /// Reviews in [from, to] (YYYY-MM-DD, inclusive), newest first.
  func fetchReviews(studentID: UUID, from: String, to: String) async throws -> [SessionReview]
}
