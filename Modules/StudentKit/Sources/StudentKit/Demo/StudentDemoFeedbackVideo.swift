import CoreModels
import Foundation

/// The demo's one video-scoped feedback item, so the association card added by
/// spec 060 is visible in the demo build rather than silently absent.
///
/// It lives in its own file because `StudentDemoSeed.swift` already sits at both
/// the `type_body_length` and `file_length` limits — folding this in pushes it
/// over either way.
///
/// No playback URL is seeded: the demo has no real clip, so tapping the card
/// exercises the "播放链接获取失败" path instead of playing.
///
/// The id is passed in rather than minted here so this keeps using the seed's
/// existing deterministic `uuid(_:)` helper — no new force unwrap.
func demoFeedbackVideo(id: UUID, loggedAt: Date) -> CoachFeedbackVideo {
  CoachFeedbackVideo(
    id: id,
    exerciseName: "低杠位深蹲",
    setIndex: 0,
    weightKg: "125.00",
    reps: 5,
    loggedAt: loggedAt
  )
}
