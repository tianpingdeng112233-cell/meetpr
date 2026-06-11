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
}
