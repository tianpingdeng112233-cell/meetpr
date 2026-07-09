import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

// Spec 051 §1: one review per training day, rewrite overwrites, blanks bounce.

private let student = UUID()

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryReviewUpsertsByDayAndKeepsIdentity() async throws {
  let repo = InMemorySessionReviewRepository()

  let first = try await repo.submitReview(
    studentID: student, reviewDate: "2026-07-04", feeling: "最后一组很稳", sessionRPE: 8)
  let second = try await repo.submitReview(
    studentID: student, reviewDate: "2026-07-04", feeling: "改主意了", sessionRPE: 8.5)

  #expect(second.id == first.id)
  #expect(second.feeling == "改主意了")
  let all = try await repo.fetchReviews(studentID: student, from: "2026-07-01", to: "2026-07-31")
  #expect(all.count == 1)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func blankFeelingIsRejected() async {
  let repo = InMemorySessionReviewRepository()
  await #expect(throws: SessionReviewRepositoryError.emptyFeeling) {
    try await repo.submitReview(
      studentID: student, reviewDate: "2026-07-04", feeling: "   ", sessionRPE: nil)
  }
}

@available(iOS 17.0, macOS 14.0, *)
@Test func fetchWindowsAreInclusiveAndNewestFirst() async throws {
  let repo = InMemorySessionReviewRepository()
  _ = try await repo.submitReview(
    studentID: student, reviewDate: "2026-07-01", feeling: "第一天", sessionRPE: nil)
  _ = try await repo.submitReview(
    studentID: student, reviewDate: "2026-07-04", feeling: "第四天", sessionRPE: nil)
  _ = try await repo.submitReview(
    studentID: student, reviewDate: "2026-06-30", feeling: "窗外", sessionRPE: nil)

  let july = try await repo.fetchReviews(studentID: student, from: "2026-07-01", to: "2026-07-31")

  #expect(july.map(\.feeling) == ["第四天", "第一天"])
}
