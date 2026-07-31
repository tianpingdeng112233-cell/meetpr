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
  private let markerRepository: any VideoMarkerRepository
  private var currentStudentID: UUID?

  public init(
    repository: any StudentFeedbackRepository,
    markerRepository: any VideoMarkerRepository = InMemoryVideoMarkerRepository()
  ) {
    self.repository = repository
    self.markerRepository = markerRepository
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
    let isInitialLoad = state == .idle
    if isInitialLoad { state = .loading }
    do {
      state = .loaded(try await repository.fetchInbox(studentID: studentID))
    } catch {
      if error.isTaskCancellation {
        if isInitialLoad { state = .idle }
        return
      }
      if case .loaded = state { return }
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

  /// Marker availability is optional while the endpoint rolls out: a 404 or
  /// transport failure hides the marker surface without blocking playback.
  /// Any other error keeps the surface visible with a failure line so the
  /// coach's markers never vanish silently.
  public func markers(videoID: UUID) async -> VideoMarkerLoadOutcome {
    do {
      return .loaded(try await markerRepository.markers(videoID: videoID))
    } catch VideoMarkerRepositoryError.unavailable {
      return .hidden
    } catch {
      // Fail safe: only a recognized not-deployed signal hides the surface;
      // cancellation aside, every other error shows a failure line.
      return error.isTaskCancellation ? .hidden : .failed
    }
  }
}

public enum VideoMarkerLoadOutcome: Equatable, Sendable {
  case hidden
  case failed
  case loaded([VideoMarker])
}
