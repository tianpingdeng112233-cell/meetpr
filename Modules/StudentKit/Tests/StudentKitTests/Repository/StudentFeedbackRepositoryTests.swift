import Foundation
import Testing

@testable import StudentKit

@Test func feedbackRepositoryFiltersInboxAndMarksRead() async throws {
  let seed = StudentDemoSeed.makeFeedback()
  let repository = InMemoryStudentFeedbackRepository(
    seed: seed, now: { StudentDemoSeed.referenceDate })

  let inbox = try await repository.fetchInbox(studentID: StudentDemoSeed.studentID)
  #expect(inbox.count == 3)
  #expect(inbox.filter { $0.readAt == nil }.count == 2)

  let unread = try #require(inbox.first { $0.readAt == nil })
  try await repository.markRead(feedbackID: unread.id)

  let updated = try await repository.fetchInbox(studentID: StudentDemoSeed.studentID)
  #expect(updated.filter { $0.readAt == nil }.count == 1)
  #expect(updated.first { $0.id == unread.id }?.readAt == StudentDemoSeed.referenceDate)
}

@Test func feedbackRepositoryIsolatesStudents() async throws {
  let repository = InMemoryStudentFeedbackRepository(seed: StudentDemoSeed.makeFeedback())

  let otherInbox = try await repository.fetchInbox(studentID: UUID())

  #expect(otherInbox.isEmpty)
}

@Test func feedbackRepositoryPostsNewUnreadFeedback() async throws {
  let repository = InMemoryStudentFeedbackRepository(
    seed: [],
    now: { StudentDemoSeed.referenceDate }
  )

  let item = try await repository.postFeedback(
    studentID: StudentDemoSeed.studentID,
    dayDate: StudentDemoSeed.referenceDate,
    planExerciseID: nil,
    text: "今天动作很稳。"
  )
  let inbox = try await repository.fetchInbox(studentID: StudentDemoSeed.studentID)

  #expect(item.text == "今天动作很稳。")
  #expect(item.readAt == nil)
  #expect(inbox.map(\.id) == [item.id])
}

@Test func feedbackRepositoryPreservesVideoIDAndResolvesPlaybackURL() async throws {
  let videoID = UUID()
  let url = try #require(URL(string: "https://oss.example.com/video.mp4"))
  let repository = InMemoryStudentFeedbackRepository(playbackURLs: [videoID: url])

  let item = try await repository.postFeedback(
    studentID: StudentDemoSeed.studentID,
    dayDate: nil,
    planExerciseID: nil,
    videoID: videoID,
    text: "视频反馈"
  )

  #expect(item.videoID == videoID)
  #expect(try await repository.playbackURL(videoID: videoID) == url)
}
