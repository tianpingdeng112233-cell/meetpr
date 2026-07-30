import CoreModels
import Foundation
import RepositoryContracts

@testable import CoachKit

enum VideoInboxFixtures {
  static let base = Date(timeIntervalSince1970: 1_780_000_000)

  static func item(
    id: UUID = UUID(),
    studentID: UUID = UUID(),
    name: String = "学员",
    setLogID: UUID? = nil,
    planExerciseID: UUID? = nil,
    exerciseName: String? = nil,
    uploadedAt: Date = base,
    sizeBytes: Int64 = 12_000_000
  ) -> PendingVideoItem {
    PendingVideoItem(
      id: id,
      studentID: studentID,
      studentDisplayName: name,
      setLogID: setLogID,
      planExerciseID: planExerciseID,
      exerciseName: exerciseName,
      dayDate: nil,
      uploadedAt: uploadedAt,
      sizeBytes: sizeBytes
    )
  }

  static func video(
    id: UUID = UUID(),
    setLogID: UUID? = nil,
    planExerciseID: UUID?,
    createdAt: Date
  ) -> StudentVideo {
    StudentVideo(
      id: id,
      setLogID: setLogID,
      planExerciseID: planExerciseID,
      contentType: "video/mp4",
      sizeBytes: 10_000_000,
      filename: nil,
      createdAt: createdAt,
      loggedAt: createdAt
    )
  }
}

/// Coach video wall keyed per student (the shared `StubCoachStudentVideoRepository`
/// returns the same list for every id; the aggregator needs per-student videos).
actor PerStudentVideoRepo: CoachStudentVideoRepository {
  private let byStudent: [UUID: [StudentVideo]]
  private let urls: [UUID: URL]

  init(_ byStudent: [UUID: [StudentVideo]], urls: [UUID: URL] = [:]) {
    self.byStudent = byStudent
    self.urls = urls
  }

  func fetchVideos(studentID: UUID) async throws -> [StudentVideo] {
    (byStudent[studentID] ?? []).sorted { $0.createdAt > $1.createdAt }
  }

  func playbackURL(videoID: UUID) async throws -> URL {
    urls[videoID] ?? URL(fileURLWithPath: "/tmp/\(videoID).mp4")
  }
}

/// Scriptable inbox repo for ViewModel tests: fails on demand, drops on send.
actor StubVideoQueueRepo: CoachVideoQueueRepository {
  private(set) var pending: [PendingVideoItem]
  var fetchError: Error?
  var sendError: Error?

  init(pending: [PendingVideoItem] = [], fetchError: Error? = nil, sendError: Error? = nil) {
    self.pending = pending
    self.fetchError = fetchError
    self.sendError = sendError
  }

  func fetchPendingVideos() async throws -> [PendingVideoItem] {
    if let fetchError { throw fetchError }
    return pending
  }

  func playbackURL(videoID: UUID) async throws -> URL {
    URL(fileURLWithPath: "/tmp/\(videoID).mp4")
  }

  func sendFeedback(for item: PendingVideoItem, text: String) async throws -> CoachFeedback {
    if let sendError { throw sendError }
    pending.removeAll { $0.id == item.id }
    return CoachFeedback(
      id: UUID(), coachID: UUID(), studentID: item.studentID, text: text, postedAt: Date())
  }
}
