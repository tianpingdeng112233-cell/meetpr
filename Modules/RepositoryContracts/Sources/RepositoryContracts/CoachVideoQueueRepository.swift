import CoreModels
import Foundation

/// One student-uploaded training video awaiting the coach's text feedback —
/// a row in the cross-student 训练视频 inbox (spec 042). Bridges the per-student
/// `StudentVideo` metadata with the student's identity so the inbox can list
/// "谁 · 哪个动作 · 何时上传" without re-fetching the roster per row.
public struct PendingVideoItem: Hashable, Identifiable, Sendable {
  /// `StudentVideo.id` — also the playback-URL exchange key.
  public let id: UUID
  public let studentID: UUID
  public let studentDisplayName: String
  /// `StudentVideo.setLogID` — resolves the four set metrics in the coach
  /// feedback workbench. Nil for an upload that is not linked to a logged set.
  public let setLogID: UUID?
  /// Feedback scope — the plan exercise the video is linked to (nil if unlinked).
  public let planExerciseID: UUID?
  /// Display only; nil when the inbox can't resolve a name (e.g. the live
  /// aggregate path, which carries metadata but not the plan).
  public let exerciseName: String?
  /// Feedback scope — the training day the linked set was logged (nil if unlinked).
  public let dayDate: Date?
  /// Newest-first sort key (`StudentVideo.displayDate`).
  public let uploadedAt: Date
  public let sizeBytes: Int64

  public init(
    id: UUID,
    studentID: UUID,
    studentDisplayName: String,
    setLogID: UUID? = nil,
    planExerciseID: UUID? = nil,
    exerciseName: String? = nil,
    dayDate: Date? = nil,
    uploadedAt: Date,
    sizeBytes: Int64
  ) {
    self.id = id
    self.studentID = studentID
    self.studentDisplayName = studentDisplayName
    self.setLogID = setLogID
    self.planExerciseID = planExerciseID
    self.exerciseName = exerciseName
    self.dayDate = dayDate
    self.uploadedAt = uploadedAt
    self.sizeBytes = sizeBytes
  }
}

/// Cross-student "训练视频" inbox queue (spec 042, PRD §5 #7). The coach side of
/// the video-feedback loop: list every bound student's uploaded video that has
/// no coach feedback yet, play one, and send text feedback (which drops it from
/// the queue). No new backend endpoint — the live impl aggregates the existing
/// per-student `GET /students/:id/videos` + `/feedback` (same client-aggregation
/// strategy as spec 029's e1RM).
public protocol CoachVideoQueueRepository: Sendable {
  /// All bound students' uploaded videos lacking coach feedback, newest-first.
  func fetchPendingVideos() async throws -> [PendingVideoItem]
  /// Short-lived presigned playback URL for one pending video.
  func playbackURL(videoID: UUID) async throws -> URL
  /// Post text feedback for the video's student, scoped to its day/exercise.
  /// Returns the saved feedback; the video then drops out of `fetchPendingVideos`.
  func sendFeedback(for item: PendingVideoItem, text: String) async throws -> CoachFeedback
}
