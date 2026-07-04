import CoreModels
import Foundation
import Networking
import RepositoryContracts

public actor BackendSessionReviewRepository: SessionReviewRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  @discardableResult
  public func submitReview(
    studentID: UUID,
    reviewDate: String,
    feeling: String,
    sessionRPE: Decimal?
  ) async throws -> SessionReview {
    let trimmed = feeling.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw SessionReviewRepositoryError.emptyFeeling }
    let token = try await session.accessToken()
    let dto = try await api.submitSessionReview(
      date: reviewDate,
      SubmitSessionReviewRequestDTO(feeling: trimmed, sessionRpe: sessionRPE),
      accessToken: token
    )
    return dto.toDomain()
  }

  public func fetchReviews(
    studentID: UUID, from: String, to: String
  ) async throws -> [SessionReview] {
    let token = try await session.accessToken()
    let response = try await api.studentSessionReviews(
      studentID: studentID, from: from, to: to, accessToken: token)
    return response.reviews.map { $0.toDomain() }
  }
}

extension SessionReviewDTO {
  func toDomain() -> SessionReview {
    SessionReview(
      id: id,
      studentID: studentID,
      reviewDate: reviewDate,
      feeling: feeling,
      sessionRPE: sessionRpe,
      updatedAt: updatedAt
    )
  }
}

public actor InMemorySessionReviewRepository: SessionReviewRepository {
  private var reviewsByStudent: [UUID: [String: SessionReview]] = [:]
  private let now: @Sendable () -> Date

  public init(seed: [SessionReview] = [], now: @escaping @Sendable () -> Date = Date.init) {
    self.now = now
    for review in seed {
      reviewsByStudent[review.studentID, default: [:]][review.reviewDate] = review
    }
  }

  @discardableResult
  public func submitReview(
    studentID: UUID,
    reviewDate: String,
    feeling: String,
    sessionRPE: Decimal?
  ) async throws -> SessionReview {
    let trimmed = feeling.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw SessionReviewRepositoryError.emptyFeeling }
    // Same day keeps its identity across rewrites, like the backend upsert.
    let existing = reviewsByStudent[studentID]?[reviewDate]
    let review = SessionReview(
      id: existing?.id ?? UUID(),
      studentID: studentID,
      reviewDate: reviewDate,
      feeling: trimmed,
      sessionRPE: sessionRPE,
      updatedAt: now()
    )
    reviewsByStudent[studentID, default: [:]][reviewDate] = review
    return review
  }

  public func fetchReviews(
    studentID: UUID, from: String, to: String
  ) async throws -> [SessionReview] {
    (reviewsByStudent[studentID] ?? [:]).values
      .filter { $0.reviewDate >= from && $0.reviewDate <= to }
      .sorted { $0.reviewDate > $1.reviewDate }
  }
}
