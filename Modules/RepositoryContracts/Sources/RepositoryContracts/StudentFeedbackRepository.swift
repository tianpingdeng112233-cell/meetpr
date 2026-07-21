import CoreModels
import Foundation

/// The student's coach-feedback inbox.
///
/// Demo/test seeding is intentionally NOT on this protocol: the in-memory impl
/// seeds via its own initializer at the composition root, so the protocol stays
/// clean and the backend impl carries no no-op seed method (refines spec 024 §3.3).
public protocol StudentFeedbackRepository: Sendable {
  func fetchInbox(studentID: UUID) async throws -> [CoachFeedback]
  func postFeedback(
    studentID: UUID,
    dayDate: Date?,
    planExerciseID: UUID?,
    text: String
  ) async throws -> CoachFeedback
  func postFeedback(
    studentID: UUID,
    dayDate: Date?,
    planExerciseID: UUID?,
    videoID: UUID?,
    text: String
  ) async throws -> CoachFeedback
  /// Exchanges a fresh short-lived URL for a video linked from feedback.
  func playbackURL(videoID: UUID) async throws -> URL
  func markRead(feedbackID: UUID) async throws
}

public enum StudentFeedbackRepositoryError: Error, Equatable, Sendable {
  case videoPlaybackUnavailable
}

extension StudentFeedbackRepository {
  public func postFeedback(
    studentID: UUID,
    dayDate: Date?,
    planExerciseID: UUID?,
    videoID: UUID?,
    text: String
  ) async throws -> CoachFeedback {
    try await postFeedback(
      studentID: studentID,
      dayDate: dayDate,
      planExerciseID: planExerciseID,
      text: text
    )
  }

  public func playbackURL(videoID: UUID) async throws -> URL {
    throw StudentFeedbackRepositoryError.videoPlaybackUnavailable
  }
}
