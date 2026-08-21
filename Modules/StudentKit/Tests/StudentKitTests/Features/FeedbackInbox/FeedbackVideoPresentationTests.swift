import CoreModels
import Foundation
import Testing

@testable import StudentKit

/// Feedback serialization returns the zero-based `set_logs.set_index` verbatim;
/// the card owns the display-boundary conversion.
@Test func feedbackVideoSummaryDisplaysFirstZeroBasedSetAsOne() {
  let video = CoachFeedbackVideo(
    id: UUID(),
    exerciseName: "暂停深蹲",
    setIndex: 0,
    weightKg: "125.00",
    reps: 5,
    loggedAt: Date()
  )

  #expect(FeedbackVideoPresentation.summary(video) == "暂停深蹲 · 第1组 · 125kg×5次")
}

@Test func feedbackVideoBadgeCarriesBackendRPEWhenPresent() {
  let video = CoachFeedbackVideo(
    id: UUID(),
    exerciseName: "传统硬拉",
    setIndex: 3,
    weightKg: "180.00",
    reps: 4,
    rpe: "8.5",
    loggedAt: Date()
  )

  #expect(FeedbackVideoPresentation.badge(video).rpe == 8.5)
}

@Test func feedbackVideoBadgeConvertsSetIndexAtStudentDisplayBoundary() {
  let video = CoachFeedbackVideo(
    id: UUID(),
    exerciseName: "暂停深蹲",
    setIndex: 0,
    weightKg: "125.50",
    reps: 5,
    loggedAt: Date()
  )

  let badge = FeedbackVideoPresentation.badge(video)

  #expect(badge.exerciseName == "暂停深蹲")
  #expect(badge.weightKg == 125.5)
  #expect(badge.reps == 5)
  #expect(badge.rpe == nil)
  #expect(badge.setOrdinal == 1)
  #expect(badge.coachName == nil)
}

@Test func feedbackVideoSummaryUsesEnglishExerciseNameInEnglishLocale() {
  let video = CoachFeedbackVideo(
    id: UUID(),
    exerciseName: "暂停深蹲",
    exerciseNameEn: "Pause Squat",
    setIndex: 0
  )

  #expect(
    FeedbackVideoPresentation.summary(video, locale: Locale(identifier: "en"))
      == "Pause Squat · Set 1"
  )
}

/// A freely recorded clip has no set log, so every joined field comes back null.
/// The card must degrade to the parts it has rather than print "第0组 · kg×次".
@Test func feedbackVideoSummaryDropsMissingParts() {
  let bare = CoachFeedbackVideo(id: UUID())
  #expect(FeedbackVideoPresentation.summary(bare) == "")

  let nameOnly = CoachFeedbackVideo(id: UUID(), exerciseName: "暂停深蹲")
  #expect(FeedbackVideoPresentation.summary(nameOnly) == "暂停深蹲")

  let noLoad = CoachFeedbackVideo(id: UUID(), exerciseName: "暂停深蹲", setIndex: 2)
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
