import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// One local calendar day of the video wall, newest day first.
struct StudentVideoDaySection: Hashable, Identifiable, Sendable {
  let day: Date
  let videos: [StudentVideo]

  var id: Date { day }
}

/// A resolved short-lived playback URL, presented full screen.
struct StudentVideoPlaybackItem: Identifiable, Equatable, Sendable {
  let id: UUID
  let url: URL
}

/// Playback state for the coach video grid: the metadata wall itself is
/// loaded by `StudentDetailViewModel`; this model only exchanges a tapped
/// video id for its presigned URL.
@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class StudentVideoGridViewModel {
  private(set) var loadingVideoID: UUID?
  private(set) var playbackError: String?
  var playbackItem: StudentVideoPlaybackItem?

  @ObservationIgnored private let repository: any CoachStudentVideoRepository

  init(repository: any CoachStudentVideoRepository) {
    self.repository = repository
  }

  /// Fresh 15-minute URL for in-player retry after expiry (Codex P1).
  func freshPlaybackURL(videoID: UUID) async throws -> URL {
    try await repository.playbackURL(videoID: videoID)
  }

  func play(_ video: StudentVideo) async {
    guard loadingVideoID == nil else { return }
    playbackError = nil
    loadingVideoID = video.id
    defer { loadingVideoID = nil }
    do {
      let url = try await repository.playbackURL(videoID: video.id)
      playbackItem = StudentVideoPlaybackItem(id: video.id, url: url)
    } catch {
      playbackError = "播放链接获取失败，请重试"
    }
  }

  func clearPlaybackError() {
    playbackError = nil
  }

  /// Groups the wall by the student's training day (`loggedAt`, falling back
  /// to upload time for unlinked videos), newest day first.
  static func makeSections(
    videos: [StudentVideo],
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> [StudentVideoDaySection] {
    let grouped = Dictionary(grouping: videos) { video in
      CoachFeatureCalendar.startOfDay(video.displayDate, calendar: calendar)
    }
    return
      grouped
      .map { day, dayVideos in
        StudentVideoDaySection(
          day: day,
          videos: dayVideos.sorted { $0.displayDate > $1.displayDate }
        )
      }
      .sorted { $0.day > $1.day }
  }
}
