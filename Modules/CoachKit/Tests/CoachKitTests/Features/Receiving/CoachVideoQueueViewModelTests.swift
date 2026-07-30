import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func videoQueueLoadsItemsNewestFirst() async {
  let older = VideoInboxFixtures.item(uploadedAt: VideoInboxFixtures.base)
  let newer = VideoInboxFixtures.item(uploadedAt: VideoInboxFixtures.base.addingTimeInterval(60))
  let viewModel = CoachVideoQueueViewModel(
    repository: InMemoryCoachVideoQueueRepository(seed: [older, newer]))

  await viewModel.loadIfNeeded()

  #expect(viewModel.state == .loaded)
  #expect(viewModel.pendingCount == 2)
  #expect(viewModel.items.map(\.id) == [newer.id, older.id])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func videoQueueSendFeedbackDropsRowAndToasts() async {
  let item = VideoInboxFixtures.item()
  let viewModel = CoachVideoQueueViewModel(
    repository: InMemoryCoachVideoQueueRepository(seed: [item]))
  await viewModel.loadIfNeeded()

  let sent = await viewModel.sendFeedback(for: item, text: "深蹲底部停顿一下")

  #expect(sent)
  #expect(viewModel.items.isEmpty)
  #expect(viewModel.pendingCount == 0)
  #expect(viewModel.toastMessage != nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func videoQueueRejectsBlankFeedbackWithoutDropping() async {
  let item = VideoInboxFixtures.item()
  let viewModel = CoachVideoQueueViewModel(
    repository: InMemoryCoachVideoQueueRepository(seed: [item]))
  await viewModel.loadIfNeeded()

  let sent = await viewModel.sendFeedback(for: item, text: "   ")

  #expect(!sent)
  #expect(viewModel.items.count == 1)
  #expect(viewModel.bannerMessage != nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func videoQueueLoadFailureMovesToFailed() async {
  let viewModel = CoachVideoQueueViewModel(
    repository: StubVideoQueueRepo(fetchError: CoachFeatureTestError()))

  await viewModel.loadIfNeeded()

  #expect(viewModel.state == .failed)
  #expect(viewModel.pendingCount == 0)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func videoQueueSendFailureKeepsRowAndBanners() async {
  let item = VideoInboxFixtures.item()
  let viewModel = CoachVideoQueueViewModel(
    repository: StubVideoQueueRepo(pending: [item], sendError: CoachFeatureTestError()))
  await viewModel.loadIfNeeded()
  #expect(viewModel.pendingCount == 1)

  let sent = await viewModel.sendFeedback(for: item, text: "x")

  #expect(!sent)
  #expect(viewModel.items.count == 1)
  #expect(viewModel.bannerMessage != nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func studentGroupsAreOnePerStudentNewestUploadFirst() async {
  let studentA = UUID()
  let studentB = UUID()
  let base = VideoInboxFixtures.base
  let viewModel = CoachVideoQueueViewModel(
    repository: InMemoryCoachVideoQueueRepository(seed: [
      VideoInboxFixtures.item(studentID: studentA, name: "甲", uploadedAt: base),
      VideoInboxFixtures.item(
        studentID: studentA, name: "甲", uploadedAt: base.addingTimeInterval(3_600)),
      VideoInboxFixtures.item(
        studentID: studentB, name: "乙", uploadedAt: base.addingTimeInterval(7_200)),
    ]))
  await viewModel.loadIfNeeded()

  let groups = viewModel.studentGroups
  #expect(groups.count == 2)
  #expect(groups.map(\.studentName) == ["乙", "甲"])  // 乙's upload is newest
  #expect(groups.first { $0.studentID == studentA }?.count == 2)
  #expect(viewModel.pendingCount == 3)  // tab count still totals videos, not students
  #expect(viewModel.items(for: studentA).count == 2)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func daySectionsGroupByTrainingDayNewestFirst() {
  let day1 = VideoInboxFixtures.base
  let day2 = day1.addingTimeInterval(86_400 + 3_600)  // next calendar day
  let sections = CoachVideoQueueViewModel.daySections([
    VideoInboxFixtures.item(uploadedAt: day1.addingTimeInterval(3_600)),
    VideoInboxFixtures.item(uploadedAt: day1.addingTimeInterval(7_200)),
    VideoInboxFixtures.item(uploadedAt: day2),
  ])

  #expect(sections.count == 2)
  #expect(sections.first?.items.count == 1)  // newest day on top
  #expect(sections.last?.items.count == 2)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func staleRefreshCannotRestoreVideoAfterFeedbackSend() async {
  let item = VideoInboxFixtures.item()
  let repository = StaleRefreshVideoQueueRepository(pending: [item])
  let viewModel = CoachVideoQueueViewModel(repository: repository)
  await viewModel.loadIfNeeded()

  let staleRefresh = Task {
    await viewModel.refresh()
  }
  while await repository.fetchCallCount < 2 {
    await Task.yield()
  }

  let sent = await viewModel.sendFeedback(for: item, text: "保持背部张力")
  await staleRefresh.value

  #expect(sent)
  #expect(viewModel.items.isEmpty)
  #expect(viewModel.pendingCount == 0)
}

private actor StaleRefreshVideoQueueRepository: CoachVideoQueueRepository {
  private var pending: [PendingVideoItem]
  private(set) var fetchCallCount = 0

  init(pending: [PendingVideoItem]) {
    self.pending = pending
  }

  func fetchPendingVideos() async throws -> [PendingVideoItem] {
    fetchCallCount += 1
    let snapshot = pending
    if fetchCallCount > 1 {
      try? await Task.sleep(for: .milliseconds(80))
    }
    return snapshot
  }

  func playbackURL(videoID: UUID) async throws -> URL {
    URL(fileURLWithPath: "/tmp/\(videoID).mp4")
  }

  func sendFeedback(for item: PendingVideoItem, text: String) async throws -> CoachFeedback {
    pending.removeAll { $0.id == item.id }
    return CoachFeedback(
      id: UUID(),
      coachID: UUID(),
      studentID: item.studentID,
      videoID: item.id,
      text: text,
      postedAt: VideoInboxFixtures.base
    )
  }
}
