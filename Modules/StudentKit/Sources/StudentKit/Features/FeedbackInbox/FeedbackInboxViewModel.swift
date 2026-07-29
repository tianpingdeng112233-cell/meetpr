import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class FeedbackInboxViewModel {
  public enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded([CoachFeedback])
    case error(String)
  }

  public private(set) var state: State = .idle

  private let repository: any StudentFeedbackRepository
  private var currentStudentID: UUID?

  public init(repository: any StudentFeedbackRepository) {
    self.repository = repository
  }

  public var items: [CoachFeedback] {
    guard case .loaded(let items) = state else {
      return []
    }
    return items
  }

  public var unreadCount: Int {
    items.filter { $0.readAt == nil }.count
  }

  public var hasFinishedLoading: Bool {
    if case .loaded = state {
      return true
    }
    return false
  }

  public var isLoadedEmpty: Bool {
    if case .loaded(let items) = state {
      return items.isEmpty
    }
    return false
  }

  public func load(studentID: UUID) async {
    currentStudentID = studentID
    state = .loading
    do {
      state = .loaded(try await repository.fetchInbox(studentID: studentID))
    } catch {
      if error.isTaskCancellation {
        state = .idle
        return
      }
      state = .error(error.localizedDescription)
    }
  }

  public func markRead(_ item: CoachFeedback) async {
    do {
      try await repository.markRead(feedbackID: item.id)
      if let studentID = currentStudentID {
        state = .loaded(try await repository.fetchInbox(studentID: studentID))
      }
    } catch {
      // A cancelled mark-read task must leave the loaded inbox intact.
      if error.isTaskCancellation { return }
      state = .error(error.localizedDescription)
    }
  }

  /// Exchanges a fresh URL both for the initial tap and for in-player expiry retry.
  public func playbackURL(videoID: UUID) async throws -> URL {
    try await repository.playbackURL(videoID: videoID)
  }
}
