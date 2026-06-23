import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Coach 训练视频 inbox queue (spec 042). Mirrors `BindQueueViewModel`: loads
/// the cross-student pending-video list, feeds the 训练视频 tab count, and drops
/// a row once the coach sends feedback for it.
@Observable
@MainActor
final class CoachVideoQueueViewModel {
  enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
  }

  var state: LoadState = .idle
  private(set) var items: [PendingVideoItem] = []
  var bannerMessage: String?
  var toastMessage: String?

  /// Total pending videos across all students — drives the 训练视频 tab count.
  var pendingCount: Int { items.count }

  /// One row per student (spec 042 D1: inbox aggregates by person), newest
  /// upload first. Tapping a row opens that student's day-grouped videos.
  var studentGroups: [PendingVideoStudentGroup] {
    Dictionary(grouping: items, by: \.studentID)
      .map { studentID, videos in
        PendingVideoStudentGroup(
          studentID: studentID,
          studentName: videos.first?.studentDisplayName ?? "",
          count: videos.count,
          latestUploadedAt: videos.map(\.uploadedAt).max() ?? .distantPast
        )
      }
      .sorted { $0.latestUploadedAt > $1.latestUploadedAt }
  }

  /// One student's pending videos, newest first.
  func items(for studentID: UUID) -> [PendingVideoItem] {
    items.filter { $0.studentID == studentID }.sorted { $0.uploadedAt > $1.uploadedAt }
  }

  /// A student's pending videos grouped by training day (newest day first;
  /// newest video first within a day). One day can hold squat + bench + deadlift.
  static func daySections(_ items: [PendingVideoItem]) -> [PendingVideoDaySection] {
    Dictionary(grouping: items) { item in
      CoachFeatureCalendar.startOfDay(item.dayDate ?? item.uploadedAt)
    }
    .map { day, dayItems in
      PendingVideoDaySection(day: day, items: dayItems.sorted { $0.uploadedAt > $1.uploadedAt })
    }
    .sorted { $0.day > $1.day }
  }

  @ObservationIgnored private let repository: any CoachVideoQueueRepository

  init(repository: any CoachVideoQueueRepository) {
    self.repository = repository
  }

  func loadIfNeeded() async {
    guard state == .idle else { return }
    await refresh()
  }

  func refresh() async {
    if state == .idle { state = .loading }
    do {
      items = try await repository.fetchPendingVideos()
      state = .loaded
    } catch {
      // Keep the last snapshot on transport failure; an empty failed queue
      // collapses the segment, same as empty.
      if state != .loaded { state = .failed }
    }
  }

  func playbackURL(videoID: UUID) async throws -> URL {
    try await repository.playbackURL(videoID: videoID)
  }

  /// True on success — the video drops out of the queue and the tab count -1.
  func sendFeedback(for item: PendingVideoItem, text: String) async -> Bool {
    bannerMessage = nil
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      bannerMessage = "反馈不能为空"
      return false
    }
    do {
      _ = try await repository.sendFeedback(for: item, text: trimmed)
      items.removeAll { $0.id == item.id }
      toastMessage = "已发送反馈"
      return true
    } catch {
      bannerMessage = "发送失败,请稍后重试"
      return false
    }
  }
}

/// One inbox row: a student with N pending videos (spec 042 D1).
struct PendingVideoStudentGroup: Identifiable, Hashable, Sendable {
  let studentID: UUID
  let studentName: String
  let count: Int
  let latestUploadedAt: Date

  var id: UUID { studentID }
}

/// One training day of a student's pending videos.
struct PendingVideoDaySection: Identifiable, Hashable, Sendable {
  let day: Date
  let items: [PendingVideoItem]

  var id: Date { day }
}
