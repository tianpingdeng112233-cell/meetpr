import CoreModels
import Foundation

/// The student's coach-feedback inbox.
///
/// Demo/test seeding is intentionally NOT on this protocol: the in-memory impl
/// seeds via its own initializer at the composition root, so the protocol stays
/// clean and the backend impl carries no no-op seed method (refines spec 024 §3.3).
public protocol StudentFeedbackRepository: Sendable {
  func fetchInbox(studentID: UUID) async throws -> [CoachFeedback]
  func markRead(feedbackID: UUID) async throws
}
