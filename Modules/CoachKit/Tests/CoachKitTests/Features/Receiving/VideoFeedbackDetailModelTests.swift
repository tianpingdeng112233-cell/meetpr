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

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("marker actions update the current item and marker load failures stay hidden")
func markerActionsAndSilentFailure() async throws {
  let item = VideoInboxFixtures.item()
  let playbackURL = URL(fileURLWithPath: "/tmp/marker-video.mp4")
  let queue = CoachVideoQueueViewModel(
    repository: InMemoryCoachVideoQueueRepository(
      seed: [item],
      playbackURLs: [item.id: playbackURL]
    )
  )
  await queue.loadIfNeeded()
  let repository = InMemoryVideoMarkerRepository(coachID: UUID())
  let model = VideoFeedbackDetailModel(item: item)
  await model.prepare(
    videoQueue: queue,
    trainingLogs: EmptyStudentTrainingLogRepository(),
    markerRepository: repository
  )

  #expect(model.markers == [])
  await model.createMarker(
    timeMilliseconds: 1_250,
    level: .bad,
    note: "Depth",
    using: repository
  )
  let marker = try #require(model.markers?.first)
  #expect(marker.timeMilliseconds == 1_250)
  #expect(marker.level == .bad)

  await model.deleteMarker(marker, using: repository)
  #expect(model.markers == [])

  await model.prepare(
    videoQueue: queue,
    trainingLogs: EmptyStudentTrainingLogRepository(),
    markerRepository: FailingCoachVideoMarkerRepository(error: .unavailable)
  )
  #expect(model.markers == nil)
  #expect(!model.markersFailed)

  await model.prepare(
    videoQueue: queue,
    trainingLogs: EmptyStudentTrainingLogRepository(),
    markerRepository: FailingCoachVideoMarkerRepository(error: .failed)
  )
  #expect(model.markers == nil)
  #expect(model.markersFailed)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("marker write failures surface instead of silently dropping the action")
func markerWriteFailuresSurface() async throws {
  let item = VideoInboxFixtures.item()
  let queue = CoachVideoQueueViewModel(
    repository: InMemoryCoachVideoQueueRepository(
      seed: [item],
      playbackURLs: [item.id: URL(fileURLWithPath: "/tmp/marker-video.mp4")]
    )
  )
  await queue.loadIfNeeded()
  let repository = InMemoryVideoMarkerRepository(coachID: UUID())
  let model = VideoFeedbackDetailModel(item: item)
  await model.prepare(
    videoQueue: queue,
    trainingLogs: EmptyStudentTrainingLogRepository(),
    markerRepository: repository
  )
  await model.createMarker(
    timeMilliseconds: 700,
    level: .info,
    note: "",
    using: repository
  )
  let marker = try #require(model.markers?.first)

  let failing = FailingCoachVideoMarkerRepository(error: .failed)
  await model.createMarker(
    timeMilliseconds: 900,
    level: .warn,
    note: "Lockout",
    using: failing
  )
  #expect(model.markerActionFailure == .save)
  #expect(model.markers == [marker])

  await model.deleteMarker(marker, using: failing)
  #expect(model.markerActionFailure == .delete)
  #expect(model.markers == [marker])

  // The next successful action clears the failure banner.
  await model.deleteMarker(marker, using: repository)
  #expect(model.markerActionFailure == nil)
  #expect(model.markers == [])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("markers resolved for a previous video never render under a newer one")
func staleMarkerResultsAreRejected() async throws {
  let fixture = RapidItemChangeFixture()
  let queueViewModel = CoachVideoQueueViewModel(repository: fixture.videoRepository)
  await queueViewModel.loadIfNeeded()
  let markerRepository = InMemoryVideoMarkerRepository(coachID: UUID())
  let staleMarker = try await markerRepository.createMarker(
    videoID: fixture.first.id,
    timeMilliseconds: 3_000,
    level: .bad,
    note: "Old video"
  )
  let delayedMarkers = DelayedVideoMarkerRepository(
    wrapping: markerRepository,
    delays: [fixture.first.id: .milliseconds(80)]
  )
  let model = VideoFeedbackDetailModel(item: fixture.first)

  let firstLoad = Task {
    await model.prepare(
      videoQueue: queueViewModel,
      trainingLogs: fixture.trainingLogs,
      markerRepository: delayedMarkers
    )
  }
  while await delayedMarkers.requestCount < 1 {
    await Task.yield()
  }
  // The first load is deliberately NOT cancelled: its delayed marker response
  // arrives while the task is still live, so only the request-token and
  // item-identity guards can reject it.
  model.select(fixture.second)
  let secondLoad = Task {
    await model.prepare(
      videoQueue: queueViewModel,
      trainingLogs: fixture.trainingLogs,
      markerRepository: delayedMarkers
    )
  }

  await secondLoad.value
  await firstLoad.value

  #expect(model.currentItem.id == fixture.second.id)
  #expect(model.markers?.contains(staleMarker) == false)
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

private struct FailingCoachVideoMarkerRepository: VideoMarkerRepository {
  let error: VideoMarkerRepositoryError

  func markers(videoID: UUID) async throws -> [VideoMarker] {
    throw error
  }

  func createMarker(
    videoID: UUID,
    timeMilliseconds: Int,
    level: VideoMarkerLevel,
    note: String
  ) async throws -> VideoMarker {
    throw error
  }

  func deleteMarker(videoID: UUID, markerID: UUID) async throws {
    throw error
  }
}

private actor DelayedVideoMarkerRepository: VideoMarkerRepository {
  private let wrapped: any VideoMarkerRepository
  private let delays: [UUID: Duration]
  private(set) var requestCount = 0

  init(wrapping wrapped: any VideoMarkerRepository, delays: [UUID: Duration]) {
    self.wrapped = wrapped
    self.delays = delays
  }

  func markers(videoID: UUID) async throws -> [VideoMarker] {
    requestCount += 1
    if let delay = delays[videoID] {
      try? await Task.sleep(for: delay)
    }
    return try await wrapped.markers(videoID: videoID)
  }

  func createMarker(
    videoID: UUID,
    timeMilliseconds: Int,
    level: VideoMarkerLevel,
    note: String
  ) async throws -> VideoMarker {
    try await wrapped.createMarker(
      videoID: videoID,
      timeMilliseconds: timeMilliseconds,
      level: level,
      note: note
    )
  }

  func deleteMarker(videoID: UUID, markerID: UUID) async throws {
    try await wrapped.deleteMarker(videoID: videoID, markerID: markerID)
  }
}
