import CoreModels
import Foundation
import Testing

@testable import StudentKit

/// `set_logs.set_index` is already 1-based on the wire, and plan-web renders the
/// same field verbatim — so set 2 must read 第2组 on both ends, not 第3组.
/// (`SetDisplayNumber` solves the 0-vs-1-based mix by row position, but that
/// needs the sibling sets; a feedback card only ever holds one clip.)
@Test func feedbackVideoSummaryPrintsBackendSetNumberVerbatim() {
  let video = CoachFeedbackVideo(
    id: UUID(),
    exerciseName: "暂停深蹲",
    setIndex: 2,
    weightKg: "125.00",
    reps: 5,
    loggedAt: Date()
  )

  #expect(FeedbackVideoPresentation.summary(video) == "暂停深蹲 · 第2组 · 125kg×5次")
}

/// A freely recorded clip has no set log, so every joined field comes back null.
/// The card must degrade to the parts it has rather than print "第0组 · kg×次".
@Test func feedbackVideoSummaryDropsMissingParts() {
  let bare = CoachFeedbackVideo(id: UUID())
  #expect(FeedbackVideoPresentation.summary(bare) == "")

  let nameOnly = CoachFeedbackVideo(id: UUID(), exerciseName: "暂停深蹲")
  #expect(FeedbackVideoPresentation.summary(nameOnly) == "暂停深蹲")

  let noLoad = CoachFeedbackVideo(id: UUID(), exerciseName: "暂停深蹲", setIndex: 3)
  #expect(FeedbackVideoPresentation.summary(noLoad) == "暂停深蹲 · 第3组")

  let repsOnly = CoachFeedbackVideo(id: UUID(), exerciseName: "暂停深蹲", reps: 5)
  #expect(FeedbackVideoPresentation.summary(repsOnly) == "暂停深蹲 · 5次")
}

@Test func feedbackVideoAssociationDistinguishesLegacyDeletedAndAvailableStates() {
  let videoID = UUID()
  let video = CoachFeedbackVideo(
    id: videoID,
    exerciseName: "暂停深蹲",
    setIndex: 0,
    weightKg: "100.00",
    reps: 5,
    loggedAt: Date()
  )

  #expect(FeedbackVideoPresentation.association(videoID: nil, video: nil) == .none)
  #expect(
    FeedbackVideoPresentation.association(videoID: videoID, video: nil) == .unavailable
  )
  #expect(
    FeedbackVideoPresentation.association(videoID: videoID, video: video) == .available(video)
  )
}

@Test(
  arguments: [
    ("125.00", "125"),
    ("125.50", "125.5"),
    ("0.00", "0"),
    ("80", "80"),
  ])
func feedbackVideoWeightFormatting(rawValue: String, expected: String) {
  #expect(FeedbackVideoPresentation.weight(rawValue) == expected)
}

@MainActor
@Test func feedbackVideoPlayerExposesAllSupportedRateLabels() {
  #expect(StudentFeedbackVideoPlayerView.rateText(0.5) == "0.5x")
  #expect(StudentFeedbackVideoPlayerView.rateText(1.0) == "1x")
  #expect(StudentFeedbackVideoPlayerView.rateText(1.5) == "1.5x")
  #expect(StudentFeedbackVideoPlayerView.rateText(2.0) == "2x")
}
