import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

// MARK: - InMemory (demo / authoritative)

@Test func inMemoryReturnsSeedNewestFirst() async throws {
  let older = VideoInboxFixtures.item(uploadedAt: VideoInboxFixtures.base)
  let newer = VideoInboxFixtures.item(uploadedAt: VideoInboxFixtures.base.addingTimeInterval(3_600))
  let repo = InMemoryCoachVideoQueueRepository(seed: [older, newer])

  let pending = try await repo.fetchPendingVideos()

  #expect(pending.map(\.id) == [newer.id, older.id])
}

@Test func inMemorySendFeedbackDropsExactVideoAndScopesIt() async throws {
  let exercise = UUID()
  let target = VideoInboxFixtures.item(planExerciseID: exercise)
  let other = VideoInboxFixtures.item(uploadedAt: VideoInboxFixtures.base.addingTimeInterval(60))
  let repo = InMemoryCoachVideoQueueRepository(seed: [target, other])

  let saved = try await repo.sendFeedback(for: target, text: "起杠别急")

  #expect(saved.studentID == target.studentID)
  #expect(saved.planExerciseID == exercise)
  #expect(saved.text == "起杠别急")
  let after = try await repo.fetchPendingVideos()
  #expect(after.map(\.id) == [other.id])
}

@Test func inMemoryPlaybackURLHitAndMiss() async throws {
  let item = VideoInboxFixtures.item()
  let url = try #require(URL(string: "https://oss.example.com/play/seed"))
  let repo = InMemoryCoachVideoQueueRepository(
    seed: [item], playbackURLs: [item.id: url])

  #expect(try await repo.playbackURL(videoID: item.id) == url)
  await #expect(throws: InMemoryCoachVideoQueueRepository.InMemoryError.self) {
    _ = try await repo.playbackURL(videoID: UUID())
  }
}

// MARK: - Aggregating (live, client-side over per-student endpoints)

@Test func aggregatorExcludesAnsweredAndUnlinkedKeepsUnanswered() async throws {
  let studentA = UUID()
  let studentB = UUID()
  let answeredExercise = UUID()
  let answered = VideoInboxFixtures.video(
    planExerciseID: answeredExercise, createdAt: VideoInboxFixtures.base.addingTimeInterval(1))
  let unanswered = VideoInboxFixtures.video(
    planExerciseID: UUID(), createdAt: VideoInboxFixtures.base.addingTimeInterval(2))
  let unlinked = VideoInboxFixtures.video(
    planExerciseID: nil, createdAt: VideoInboxFixtures.base.addingTimeInterval(3))

  let roster = StubCoachPlanRepository(students: [
    CoachStudentFeatureFixtures.summary(id: studentA, name: "甲"),
    CoachStudentFeatureFixtures.summary(id: studentB, name: "乙"),
  ])
  let videos = PerStudentVideoRepo([
    studentA: [answered, unanswered],
    studentB: [unlinked],
  ])
  let feedback = StubFeedbackRepository(feedback: [
    CoachFeedback(
      id: UUID(), coachID: UUID(), studentID: studentA,
      planExerciseID: answeredExercise, text: "已回复", postedAt: VideoInboxFixtures.base)
  ])
  let repo = AggregatingCoachVideoQueueRepository(
    roster: roster, videos: videos, feedback: feedback,
    plans: StubStudentPlanRepository(plans: [:]))

  let pending = try await repo.fetchPendingVideos()

  // answered excluded (has feedback); unlinked excluded (no plan slot to track);
  // only the plan-linked, unanswered clip remains.
  #expect(pending.map(\.id) == [unanswered.id])
}

@Test func aggregatorLinkedClipDropsAfterSendAndRefetch() async throws {
  // The live de-queue invariant: reply to a plan-linked clip → its exercise now
  // has feedback → the clip drops on the next fetch (the BLOCKER repro).
  let student = CoachStudentFeatureFixtures.studentID
  let feedback = StubFeedbackRepository()
  let repo = AggregatingCoachVideoQueueRepository(
    roster: StubCoachPlanRepository(students: [
      CoachStudentFeatureFixtures.summary(id: student, name: "甲")
    ]),
    videos: PerStudentVideoRepo([student: [CoachStudentFeatureFixtures.video()]]),
    feedback: feedback,
    plans: StubStudentPlanRepository(plans: [student: CoachStudentFeatureFixtures.plan()]))

  let before = try await repo.fetchPendingVideos()
  #expect(before.count == 1)
  _ = try await repo.sendFeedback(for: try #require(before.first), text: "起身别松背")
  let after = try await repo.fetchPendingVideos()
  #expect(after.isEmpty)
}

@Test func aggregatorSkipsStudentsWithNoVideos() async throws {
  let withVideos = UUID()
  let empty = UUID()
  let video = VideoInboxFixtures.video(planExerciseID: UUID(), createdAt: VideoInboxFixtures.base)
  let roster = StubCoachPlanRepository(students: [
    CoachStudentFeatureFixtures.summary(id: empty, name: "空"),
    CoachStudentFeatureFixtures.summary(id: withVideos, name: "有"),
  ])
  let repo = AggregatingCoachVideoQueueRepository(
    roster: roster,
    videos: PerStudentVideoRepo([withVideos: [video]]),
    feedback: StubFeedbackRepository(),
    plans: StubStudentPlanRepository(plans: [:]))

  let pending = try await repo.fetchPendingVideos()

  #expect(pending.map(\.studentDisplayName) == ["有"])
}

@Test func aggregatorSendFeedbackPostsThroughFeedbackRepo() async throws {
  let student = UUID()
  let video = VideoInboxFixtures.video(planExerciseID: UUID(), createdAt: VideoInboxFixtures.base)
  let feedback = StubFeedbackRepository()
  let repo = AggregatingCoachVideoQueueRepository(
    roster: StubCoachPlanRepository(students: [
      CoachStudentFeatureFixtures.summary(id: student, name: "丙")
    ]),
    videos: PerStudentVideoRepo([student: [video]]),
    feedback: feedback,
    plans: StubStudentPlanRepository(plans: [:]))

  let pending = try await repo.fetchPendingVideos()
  let item = try #require(pending.first)
  _ = try await repo.sendFeedback(for: item, text: "深度不够")

  #expect(await feedback.postedTexts() == ["深度不够"])
}

@Test func aggregatorResolvesExerciseNameFromPlan() async throws {
  // The video links to a plan slot; its name must come from the coach's plan
  // (the main lift / variation), not a free-form string (spec 042 D2).
  let student = CoachStudentFeatureFixtures.studentID
  let repo = AggregatingCoachVideoQueueRepository(
    roster: StubCoachPlanRepository(students: [
      CoachStudentFeatureFixtures.summary(id: student, name: "甲")
    ]),
    videos: PerStudentVideoRepo([student: [CoachStudentFeatureFixtures.video()]]),
    feedback: StubFeedbackRepository(),
    plans: StubStudentPlanRepository(plans: [student: CoachStudentFeatureFixtures.plan()]))

  let pending = try await repo.fetchPendingVideos()

  // Fixtures.plan() programs 深蹲 at the slot the fixture video is linked to.
  #expect(pending.first?.exerciseName == "深蹲")
}

// MARK: - Demo seed

@Test func demoSeedPendingVideosAreWellFormed() {
  let videos = CoachDemoSeed.pendingVideos()

  #expect(videos.count == 6)
  #expect(Set(videos.map(\.id)).count == 6)  // unique video ids
  #expect(Set(videos.map(\.studentID)).count == 3)  // three students
  #expect(videos.allSatisfy { !$0.studentDisplayName.isEmpty })
  // Every clip is a coach-programmed 主项/变式 name (spec 042 D2).
  #expect(videos.allSatisfy { ($0.exerciseName?.isEmpty == false) })
  // 王晨曦's day pairs a main lift with its variation (3 clips).
  let topStudent = Dictionary(grouping: videos, by: \.studentID).values.map(\.count).max()
  #expect(topStudent == 3)
}
