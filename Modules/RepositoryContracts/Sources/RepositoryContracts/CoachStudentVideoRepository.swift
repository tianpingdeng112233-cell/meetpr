import CoreModels
import Foundation

/// Coach-side read access to a student's uploaded set videos (spec 029
/// second pass). Not the student-side `VideoAttachmentRepository`: the coach
/// keeps no local upload records and consumes the server-side wall.
public protocol CoachStudentVideoRepository: Sendable {
  /// Newest-first metadata (`GET /students/:id/videos`); carries no playback
  /// URLs by design.
  func fetchVideos(studentID: UUID) async throws -> [StudentVideo]
  /// Exchanges one video id for a short-lived presigned playback URL
  /// (`GET /uploads/:id/url`).
  func playbackURL(videoID: UUID) async throws -> URL
}
