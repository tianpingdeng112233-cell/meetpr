import CoreModels
import Foundation
import RepositoryContracts

/// Demo fixtures for the coach evaluation funnel (spec 033 §与 031/032 的
/// 接口契约): one pending receive-queue request plus evaluation periods for
/// the two in-evaluation preview roster students.
public enum CoachDemoSeed {
  /// Matches InMemoryPlanRepository's preview roster ids (uuid(4) 王晨曦,
  /// uuid(10) 赵安然).
  static func previewStudentID(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }

  public static let queueStudentID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x42))

  /// One pending request with the full 9-item summary (submitted 2h ago).
  public static func pendingBindRequests(now: Date = Date()) -> [CoachBindRequestItem] {
    [
      CoachBindRequestItem(
        id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x43)),
        studentId: queueStudentID,
        displayName: "陈一鸣",
        submittedAt: now.addingTimeInterval(-2 * 3_600),
        expiredAt: now.addingTimeInterval(7 * 86_400 - 2 * 3_600),
        onboarding: CoachBindRequestOnboardingSummary(
          completed: true,
          gender: .male,
          birthDate: "2001-03-15",
          weightKg: 83,
          trainingYears: 3,
          squat1RMKg: 180,
          bench1RMKg: 120,
          deadlift1RMKg: 220,
          muscleGroupsToStrengthen: [.quad, .hamstring, .shoulder],
          gymTier: .commercial,
          isCompeting: true,
          competitionDate: "2026-07-25",
          noteToCoach: "想突破 200kg 深蹲",
          uploadCount: 4
        )
      )
    ]
  }

  /// Live evaluation periods matching the preview roster's in-evaluation
  /// students (王晨曦 4 天 13 小时 / 赵安然 6 天 2 小时).
  public static func evaluationPeriods(coachId: UUID, now: Date = Date()) -> [EvaluationPeriod] {
    func period(studentByte: UInt8, bindByte: UInt8, remaining: TimeInterval) -> EvaluationPeriod {
      let expectedEnd = now.addingTimeInterval(remaining)
      return EvaluationPeriod(
        id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, studentByte)),
        studentId: previewStudentID(studentByte),
        coachId: coachId,
        bindRequestId: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, bindByte)),
        startedAt: expectedEnd.addingTimeInterval(-7 * 86_400),
        expectedEndAt: expectedEnd,
        inProgress: true,
        overdue: false
      )
    }
    return [
      period(studentByte: 4, bindByte: 4, remaining: (4 * 24 + 13) * 3_600),
      period(studentByte: 10, bindByte: 10, remaining: (6 * 24 + 2) * 3_600),
    ]
  }

  /// Video-id demo namespace (`…0003ßß`), distinct from roster / bind / eval ids.
  private static func videoID(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, byte))
  }

  private static func videoSetLogID(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, byte))
  }

  private static func videoExerciseID(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, byte))
  }

  // swiftlint:disable function_body_length
  /// Six pending 训练视频 inbox clips (spec 042) across three preview-roster
  /// students, keyed to the roster ids. Exercise names are the coach-programmed
  /// **主项 (比赛式…) + 变式** (spec 042 D2), and each multi-clip student's day
  /// pairs a main lift with its variation so the day-grouped detail shows the
  /// 主项/变式 structure. The app target maps every id to its bundled demo clip
  /// so play/pause, progress, and playback-rate controls remain interactive.
  public static func pendingVideos(now: Date = Date()) -> [PendingVideoItem] {
    [
      // 王晨曦: 深蹲日 —— 主项 + 变式, 外加卧推主项(同一天).
      PendingVideoItem(
        id: videoID(1),
        studentID: previewStudentID(4),
        studentDisplayName: "王晨曦",
        setLogID: videoSetLogID(1),
        planExerciseID: videoExerciseID(1),
        exerciseName: "比赛式深蹲",
        dayDate: now.addingTimeInterval(-2 * 3_600),
        uploadedAt: now.addingTimeInterval(-2 * 3_600),
        sizeBytes: 24_500_000),
      PendingVideoItem(
        id: videoID(2),
        studentID: previewStudentID(4),
        studentDisplayName: "王晨曦",
        setLogID: videoSetLogID(2),
        planExerciseID: videoExerciseID(2),
        exerciseName: "暂停深蹲",
        dayDate: now.addingTimeInterval(-3 * 3_600),
        uploadedAt: now.addingTimeInterval(-3 * 3_600),
        sizeBytes: 19_800_000),
      PendingVideoItem(
        id: videoID(3),
        studentID: previewStudentID(4),
        studentDisplayName: "王晨曦",
        setLogID: videoSetLogID(3),
        planExerciseID: videoExerciseID(3),
        exerciseName: "比赛式卧推",
        dayDate: now.addingTimeInterval(-4 * 3_600),
        uploadedAt: now.addingTimeInterval(-4 * 3_600),
        sizeBytes: 18_200_000),
      // 李嘉宁: 卧推日 —— 主项 + 变式.
      PendingVideoItem(
        id: videoID(4),
        studentID: previewStudentID(8),
        studentDisplayName: "李嘉宁",
        setLogID: videoSetLogID(4),
        planExerciseID: videoExerciseID(4),
        exerciseName: "比赛式卧推",
        dayDate: now.addingTimeInterval(-5 * 3_600),
        uploadedAt: now.addingTimeInterval(-5 * 3_600),
        sizeBytes: 21_300_000),
      PendingVideoItem(
        id: videoID(5),
        studentID: previewStudentID(8),
        studentDisplayName: "李嘉宁",
        setLogID: videoSetLogID(5),
        planExerciseID: videoExerciseID(5),
        exerciseName: "窄握卧推",
        dayDate: now.addingTimeInterval(-6 * 3_600),
        uploadedAt: now.addingTimeInterval(-6 * 3_600),
        sizeBytes: 15_700_000),
      // 张以恒: 硬拉日 —— 主项(昨天).
      PendingVideoItem(
        id: videoID(6),
        studentID: previewStudentID(2),
        studentDisplayName: "张以恒",
        planExerciseID: videoExerciseID(6),
        exerciseName: "比赛式传统硬拉",
        dayDate: now.addingTimeInterval(-26 * 3_600),
        uploadedAt: now.addingTimeInterval(-26 * 3_600),
        sizeBytes: 31_000_000),
    ]
  }
  // swiftlint:enable function_body_length

  // swiftlint:disable function_body_length
  /// Set-log fixtures linked to the first five queue clips. The sixth clip is
  /// intentionally unlinked so Demo can exercise the no-four-grid state.
  public static func pendingVideoSetLogs(now: Date = Date()) -> [StudentSetLog] {
    [
      StudentSetLog(
        id: videoSetLogID(1),
        studentID: previewStudentID(4),
        planExerciseID: videoExerciseID(1),
        setIndex: 4,
        loggedAt: now.addingTimeInterval(-2 * 3_600),
        weightKg: 185,
        reps: 3,
        rpe: 8,
        completed: true
      ),
      StudentSetLog(
        id: videoSetLogID(2),
        studentID: previewStudentID(4),
        planExerciseID: videoExerciseID(2),
        setIndex: 2,
        loggedAt: now.addingTimeInterval(-3 * 3_600),
        weightKg: 150,
        reps: 4,
        rpe: nil,
        completed: true
      ),
      StudentSetLog(
        id: videoSetLogID(3),
        studentID: previewStudentID(4),
        planExerciseID: videoExerciseID(3),
        setIndex: 3,
        loggedAt: now.addingTimeInterval(-4 * 3_600),
        weightKg: 112.5,
        reps: 5,
        rpe: 8.5,
        completed: true
      ),
      StudentSetLog(
        id: videoSetLogID(4),
        studentID: previewStudentID(8),
        planExerciseID: videoExerciseID(4),
        setIndex: 1,
        loggedAt: now.addingTimeInterval(-5 * 3_600),
        weightKg: 95,
        reps: 5,
        rpe: 7.5,
        completed: true
      ),
      StudentSetLog(
        id: videoSetLogID(5),
        studentID: previewStudentID(8),
        planExerciseID: videoExerciseID(5),
        setIndex: 2,
        loggedAt: now.addingTimeInterval(-6 * 3_600),
        weightKg: 82.5,
        reps: 6,
        rpe: 8,
        completed: true
      ),
    ]
  }
  // swiftlint:enable function_body_length
}
