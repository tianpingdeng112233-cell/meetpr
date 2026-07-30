import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("rapid item changes reject stale playback and set-log results")
func rapidItemChangesRejectStaleResults() async {
  let fixture = RapidItemChangeFixture()
  let queueViewModel = CoachVideoQueueViewModel(repository: fixture.videoRepository)
  await queueViewModel.loadIfNeeded()
  let model = VideoFeedbackDetailModel(item: fixture.first)

  let firstLoad = Task {
    await model.prepare(videoQueue: queueViewModel, trainingLogs: fixture.trainingLogs)
  }
  while await fixture.videoRepository.playbackRequestCount < 1 {
    await Task.yield()
  }
  while await fixture.trainingLogs.fetchRequestCount < 1 {
    await Task.yield()
  }
  model.select(fixture.second)
  firstLoad.cancel()
  let secondLoad = Task {
    await model.prepare(videoQueue: queueViewModel, trainingLogs: fixture.trainingLogs)
  }

  await secondLoad.value
  await firstLoad.value

  #expect(model.currentItem.id == fixture.second.id)
  #expect(model.playbackURL == fixture.secondURL)
  #expect(model.setInfo?.weightText == "200")
  #expect(!model.isResolvingPlayback)
  #expect(!model.playbackError)
}

private struct RapidItemChangeFixture {
  let first: PendingVideoItem
  let second: PendingVideoItem
  let secondURL = URL(fileURLWithPath: "/tmp/second.mp4")
  let videoRepository: DelayedVideoResolutionRepository
  let trainingLogs: DelayedTrainingLogRepository

  init() {
    let firstSetLogID = UUID()
    let secondSetLogID = UUID()
    let firstExerciseID = UUID()
    let secondExerciseID = UUID()
    first = VideoInboxFixtures.item(
      setLogID: firstSetLogID,
      planExerciseID: firstExerciseID
    )
    second = VideoInboxFixtures.item(
      setLogID: secondSetLogID,
      planExerciseID: secondExerciseID
    )
    videoRepository = DelayedVideoResolutionRepository(
      pending: [first, second],
      urls: [
        first.id: URL(fileURLWithPath: "/tmp/first.mp4"),
        second.id: secondURL,
      ],
      delays: [
        first.id: .milliseconds(80),
        second.id: .milliseconds(5),
      ]
    )
    trainingLogs = DelayedTrainingLogRepository(
      logsByExercise: [
        firstExerciseID: [
          setLog(id: firstSetLogID, planExerciseID: firstExerciseID, weightKg: 100)
        ],
        secondExerciseID: [
          setLog(id: secondSetLogID, planExerciseID: secondExerciseID, weightKg: 200)
        ],
      ],
      delays: [
        firstExerciseID: .milliseconds(80),
        secondExerciseID: .milliseconds(5),
      ]
    )
  }
}

private func setLog(
  id: UUID,
  planExerciseID: UUID,
  weightKg: Decimal
) -> StudentSetLog {
  StudentSetLog(
    id: id,
    studentID: UUID(),
    planExerciseID: planExerciseID,
    setIndex: 0,
    loggedAt: VideoInboxFixtures.base,
    weightKg: weightKg,
    reps: 3,
    rpe: 8,
    completed: true
  )
}

private actor DelayedVideoResolutionRepository: CoachVideoQueueRepository {
  let pending: [PendingVideoItem]
  let urls: [UUID: URL]
  let delays: [UUID: Duration]
  private(set) var playbackRequestCount = 0

  init(
    pending: [PendingVideoItem],
    urls: [UUID: URL],
    delays: [UUID: Duration]
  ) {
    self.pending = pending
    self.urls = urls
    self.delays = delays
  }

  func fetchPendingVideos() async throws -> [PendingVideoItem] {
    pending
  }

  func playbackURL(videoID: UUID) async throws -> URL {
    playbackRequestCount += 1
    if let delay = delays[videoID] {
      await Task.detached {
        try? await Task.sleep(for: delay)
      }.value
    }
    return urls[videoID] ?? URL(fileURLWithPath: "/tmp/missing.mp4")
  }

  func sendFeedback(for item: PendingVideoItem, text: String) async throws -> CoachFeedback {
    CoachFeedback(
      id: UUID(),
      coachID: UUID(),
      studentID: item.studentID,
      videoID: item.id,
      text: text,
      postedAt: VideoInboxFixtures.base
    )
  }
}

private actor DelayedTrainingLogRepository: StudentTrainingLogRepository {
  let logsByExercise: [UUID: [StudentSetLog]]
  let delays: [UUID: Duration]
  private(set) var fetchRequestCount = 0

  init(
    logsByExercise: [UUID: [StudentSetLog]],
    delays: [UUID: Duration]
  ) {
    self.logsByExercise = logsByExercise
    self.delays = delays
  }

  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    log
  }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    fetchRequestCount += 1
    if let delay = delays[planExerciseID] {
      await Task.detached {
        try? await Task.sleep(for: delay)
      }.value
    }
    return logsByExercise[planExerciseID] ?? []
  }
}
