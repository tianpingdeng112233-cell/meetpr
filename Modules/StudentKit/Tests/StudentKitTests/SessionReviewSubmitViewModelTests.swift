import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

// Spec 051 §1: submit state machine — blanks can't submit, failure keeps the
// text and offers retry, same-day reload prefills.

private let student = UUID()

private actor FailingReviews: SessionReviewRepository {
  func submitReview(
    studentID: UUID, reviewDate: String, feeling: String, sessionRPE: Decimal?
  ) async throws -> SessionReview {
    throw URLError(.notConnectedToInternet)
  }

  func fetchReviews(
    studentID: UUID, from: String, to toDay: String
  ) async throws -> [SessionReview] {
    []
  }
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func blankFeelingCannotSubmit() {
  let viewModel = SessionReviewSubmitViewModel(
    repository: InMemorySessionReviewRepository(), studentID: student, reviewDate: "2026-07-04")
  viewModel.feeling = "   "
  #expect(viewModel.canSubmit == false)
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func successfulSubmitSavesAndReloadPrefills() async throws {
  let repo = InMemorySessionReviewRepository()
  let viewModel = SessionReviewSubmitViewModel(
    repository: repo, studentID: student, reviewDate: "2026-07-04")
  viewModel.feeling = "最后一组硬拉很稳"
  viewModel.sessionRPE = 8.5

  await viewModel.submit()
  #expect(viewModel.state == .saved)

  let fresh = SessionReviewSubmitViewModel(
    repository: repo, studentID: student, reviewDate: "2026-07-04")
  await fresh.load()
  #expect(fresh.feeling == "最后一组硬拉很稳")
  #expect(fresh.sessionRPE == 8.5)
  #expect(fresh.state == .saved)
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func failureKeepsTextAndOffersRetry() async {
  let viewModel = SessionReviewSubmitViewModel(
    repository: FailingReviews(), studentID: student, reviewDate: "2026-07-04")
  viewModel.feeling = "写了一大段感受"

  await viewModel.submit()

  guard case .failed = viewModel.state else {
    Issue.record("expected .failed, got \(viewModel.state)")
    return
  }
  #expect(viewModel.feeling == "写了一大段感受")
  #expect(viewModel.canSubmit)
}
