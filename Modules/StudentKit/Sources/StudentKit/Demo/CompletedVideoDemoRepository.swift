import CoreModels
import Foundation

/// Reuses the bundled clip and existing Demo feedback; no network or persisted data.
struct CompletedVideoDemoRepository: StudentReplayVideoRepository {
  func fetchVideos(studentID: UUID) async throws -> [StudentVideo] {
    guard studentID == StudentDemoSeed.studentID else { return [] }
    let logs = StudentDemoSeed.makeHistoricalLogs(studentID: studentID)
    return logs.enumerated().compactMap { index, log in
      guard log.setIndex == 0 || log.setIndex == 1 else { return nil }
      let id = index == 0 ? StudentDemoSeed.makeFeedback().first?.videoID ?? log.id : log.id
      return StudentVideo(
        id: id, setLogID: log.id, planExerciseID: log.planExerciseID,
        contentType: "video/mp4", sizeBytes: 1, filename: "coach-demo-video.mp4",
        createdAt: log.loggedAt, loggedAt: log.loggedAt)
    }
  }

  func playbackURL(videoID: UUID) async throws -> URL {
    guard let url = Bundle.main.url(forResource: "coach-demo-video", withExtension: "mp4") else {
      throw VideoAttachmentPlaybackError.unavailable
    }
    return url
  }
}
