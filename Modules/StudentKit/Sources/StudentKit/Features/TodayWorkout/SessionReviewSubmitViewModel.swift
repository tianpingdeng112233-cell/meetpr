import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Submit state for the one-line session review (spec 051 §1): the
/// walkthrough's P0-3 fix — what the student writes must land somewhere.
/// Failure keeps the text and offers retry (no queue: a reflection is not a
/// training set).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Observable
final class SessionReviewSubmitViewModel {
  enum State: Equatable {
    case idle
    case submitting
    case saved
    case failed(String)
  }

  var feeling = ""
  var sessionRPE: Decimal?
  private(set) var state: State = .idle

  @ObservationIgnored private let repository: any SessionReviewRepository
  @ObservationIgnored private let studentID: UUID
  @ObservationIgnored private let reviewDate: String

  init(repository: any SessionReviewRepository, studentID: UUID, reviewDate: String) {
    self.repository = repository
    self.studentID = studentID
    self.reviewDate = reviewDate
  }

  var canSubmit: Bool {
    !feeling.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && state != .submitting
  }

  /// Prefill from an already-saved review of the same day (rewrite flow).
  func load() async {
    guard
      let existing = try? await repository.fetchReviews(
        studentID: studentID, from: reviewDate, to: reviewDate
      ).first
    else { return }
    feeling = existing.feeling
    sessionRPE = existing.sessionRPE
    state = .saved
  }

  func submit() async {
    guard canSubmit else { return }
    state = .submitting
    do {
      _ = try await repository.submitReview(
        studentID: studentID,
        reviewDate: reviewDate,
        feeling: feeling,
        sessionRPE: sessionRPE
      )
      state = .saved
    } catch {
      state = .failed("没保存上,再试一次")
    }
  }
}
