import CoreModels
import Foundation
import RepositoryContracts

/// Live 训练视频 inbox (spec 042) built by aggregating existing per-student
/// endpoints — **no new backend endpoint**, mirroring spec 029's "compute on the
/// client from per-student data" approach. For each bound student it pulls the
/// video wall + feedback inbox and surfaces the videos that have no coach
/// feedback scoped to their plan exercise yet.
///
/// "Answered" is matched coarsely by `planExerciseID` (the backend feedback
/// shape has no `video_id`); two videos on the same exercise can't be told
/// apart. Acceptable for V0.2 — precise per-video provenance is deferred (spec
/// 042 §不做). The demo path uses `InMemoryCoachVideoQueueRepository`,
/// which drops the exact video id and is unaffected.
public struct AggregatingCoachVideoQueueRepository: CoachVideoQueueRepository {
  private let roster: any PlanRepository
  private let videos: any CoachStudentVideoRepository
  private let feedback: any StudentFeedbackRepository
  private let plans: any StudentPlanRepository

  public init(
    roster: any PlanRepository,
    videos: any CoachStudentVideoRepository,
    feedback: any StudentFeedbackRepository,
    plans: any StudentPlanRepository
  ) {
    self.roster = roster
    self.videos = videos
    self.feedback = feedback
    self.plans = plans
  }

  public func fetchPendingVideos() async throws -> [PendingVideoItem] {
    let students = try await roster.fetchStudents()
    var items: [PendingVideoItem] = []
    for student in students {
      let studentVideos = try await videos.fetchVideos(studentID: student.id)
      guard !studentVideos.isEmpty else { continue }
      let answeredExerciseIDs = Set(
        try await feedback.fetchInbox(studentID: student.id).compactMap(\.planExerciseID)
      )
      // The video's exercise name comes from the coach's authored plan (the main
      // lift / variation the set was logged against), not a free-form string.
      let exerciseNamesByID = await exerciseNames(forStudent: student.id)
      for video in studentVideos {
        // Unlinked uploads (no plan slot) can't be feedback-tracked by
        // planExerciseID — including them would leave a clip that never drops
        // after the coach replies. Live queue carries plan-linked clips only
        // (spec 042 §不做); the demo's InMemory repo drops by exact video id.
        guard let exerciseID = video.planExerciseID else { continue }
        guard !answeredExerciseIDs.contains(exerciseID) else { continue }
        items.append(
          PendingVideoItem(
            id: video.id,
            studentID: student.id,
            studentDisplayName: student.displayName,
            planExerciseID: exerciseID,
            exerciseName: exerciseNamesByID[exerciseID],
            dayDate: video.loggedAt.map { Calendar(identifier: .gregorian).startOfDay(for: $0) },
            uploadedAt: video.displayDate,
            sizeBytes: video.sizeBytes
          )
        )
      }
    }
    return items.sorted { $0.uploadedAt > $1.uploadedAt }
  }

  /// `[planExerciseID: exercise name]` from the student's current plan — maps a
  /// video's linked slot to the coach-programmed 主项/变式 name. Empty when the
  /// plan can't be fetched (the row then shows time + size only).
  private func exerciseNames(forStudent studentID: UUID) async -> [UUID: String] {
    guard let plan = try? await plans.fetchCurrentPlan(studentID: studentID) else { return [:] }
    return Dictionary(
      plan.days.flatMap(\.exercises).map { ($0.id, $0.exercise.name) },
      uniquingKeysWith: { first, _ in first }
    )
  }

  public func playbackURL(videoID: UUID) async throws -> URL {
    try await videos.playbackURL(videoID: videoID)
  }

  public func sendFeedback(for item: PendingVideoItem, text: String) async throws -> CoachFeedback {
    try await feedback.postFeedback(
      studentID: item.studentID,
      dayDate: item.dayDate,
      planExerciseID: item.planExerciseID,
      text: text
    )
  }
}
