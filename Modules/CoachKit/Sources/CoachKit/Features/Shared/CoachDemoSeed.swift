import CoreModels
import Foundation
import RepositoryContracts

/// Demo fixtures for the coach receive queue and video inbox.
public enum CoachDemoSeed {
  /// Matches InMemoryPlanRepository's preview roster ids (uuid(4) 王晨曦,
  /// uuid(10) 赵安然).
  static func previewStudentID(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
  }

  public static let queueStudentID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x42))

  public static func dashboardSignals(now: Date = Date()) -> [CoachSignal] {
    [
      CoachSignal(
        id: signalID(1),
        studentID: previewStudentID(4),
        studentName: "王晨曦",
        type: .missedTraining,
        severity: .red,
        reason: "周一至周三无打卡（已连续 3 个训练日）",
        openedAt: now.addingTimeInterval(-1_800)
      ),
      CoachSignal(
        id: signalID(2),
        studentID: previewStudentID(2),
        studentName: "张以恒",
        type: .weightFailed,
        severity: .yellow,
        reason: "比赛式传统硬拉 210kg 被压，今天已出现 2 次失败组",
        openedAt: now.addingTimeInterval(-3_600)
      ),
      CoachSignal(
        id: signalID(3),
        studentID: previewStudentID(8),
        studentName: "李嘉宁",
        type: .personalRecord,
        severity: .green,
        reason: "卧推 e1RM 提升至 102.5kg，刷新近 28 天最佳",
        openedAt: now.addingTimeInterval(-7_200)
      ),
    ]
  }

  public static let dailyDigestBody = "昨天 · 3 练完 · 1 缺练 · 1 被压 · 1 破 PR"

  private static func signalID(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, byte))
  }

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

  /// Video-id demo namespace (`…0003ßß`), distinct from roster / bind / eval ids.
  private static func videoID(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, byte))
  }

  /// Six pending 训练视频 inbox clips (spec 042) across three preview-roster
  /// students, keyed to the roster ids. Exercise names are the coach-programmed
  /// **主项 (比赛式…) + 变式** (spec 042 D2), and each multi-clip student's day
  /// pairs a main lift with its variation so the day-grouped detail shows the
  /// 主项/变式 structure. No playback URLs — metadata-only, matching the
  /// per-student video wall demo (spec 029); list / count / 写反馈 demo fully,
  /// playback degrades gracefully.
  public static func pendingVideos(now: Date = Date()) -> [PendingVideoItem] {
    [
      // 王晨曦: 深蹲日 —— 主项 + 变式, 外加卧推主项(同一天).
      PendingVideoItem(
        id: videoID(1),
        studentID: previewStudentID(4),
        studentDisplayName: "王晨曦",
        exerciseName: "比赛式深蹲",
        uploadedAt: now.addingTimeInterval(-2 * 3_600),
        sizeBytes: 24_500_000),
      PendingVideoItem(
        id: videoID(2),
        studentID: previewStudentID(4),
        studentDisplayName: "王晨曦",
        exerciseName: "暂停深蹲",
        uploadedAt: now.addingTimeInterval(-3 * 3_600),
        sizeBytes: 19_800_000),
      PendingVideoItem(
        id: videoID(3),
        studentID: previewStudentID(4),
        studentDisplayName: "王晨曦",
        exerciseName: "比赛式卧推",
        uploadedAt: now.addingTimeInterval(-4 * 3_600),
        sizeBytes: 18_200_000),
      // 李嘉宁: 卧推日 —— 主项 + 变式.
      PendingVideoItem(
        id: videoID(4),
        studentID: previewStudentID(8),
        studentDisplayName: "李嘉宁",
        exerciseName: "比赛式卧推",
        uploadedAt: now.addingTimeInterval(-5 * 3_600),
        sizeBytes: 21_300_000),
      PendingVideoItem(
        id: videoID(5),
        studentID: previewStudentID(8),
        studentDisplayName: "李嘉宁",
        exerciseName: "窄握卧推",
        uploadedAt: now.addingTimeInterval(-6 * 3_600),
        sizeBytes: 15_700_000),
      // 张以恒: 硬拉日 —— 主项(昨天).
      PendingVideoItem(
        id: videoID(6),
        studentID: previewStudentID(2),
        studentDisplayName: "张以恒",
        exerciseName: "比赛式传统硬拉",
        uploadedAt: now.addingTimeInterval(-26 * 3_600),
        sizeBytes: 31_000_000),
    ]
  }
}
