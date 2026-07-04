import Foundation

/// A student's post-session reflection: one per training day, rewriting the
/// same day overwrites (spec 051 / backend spec 012). The walkthrough's P0-3:
/// what a student writes after training must never vanish on dismiss.
public struct SessionReview: Codable, Equatable, Sendable, Identifiable {
  public let id: UUID
  public let studentID: UUID
  /// Training day (YYYY-MM-DD, client-local — same discipline as set logs).
  public let reviewDate: String
  public let feeling: String
  public let sessionRPE: Decimal?
  public let updatedAt: Date

  public init(
    id: UUID,
    studentID: UUID,
    reviewDate: String,
    feeling: String,
    sessionRPE: Decimal? = nil,
    updatedAt: Date
  ) {
    self.id = id
    self.studentID = studentID
    self.reviewDate = reviewDate
    self.feeling = feeling
    self.sessionRPE = sessionRPE
    self.updatedAt = updatedAt
  }
}
