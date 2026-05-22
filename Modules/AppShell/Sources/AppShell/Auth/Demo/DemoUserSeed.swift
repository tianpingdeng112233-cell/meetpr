import CoreModels
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public enum DemoUserSeed {
  public static let accessToken = "demo-access-2026-05-10"
  public static let refreshToken = "demo-refresh-2026-05-10"

  public static let coach = User(
    id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
    phone: "13800000000",
    name: "演示教练",
    unitSystem: .metric,
    role: .coach,
    createdAt: timestamp,
    updatedAt: timestamp
  )

  /// Mirrors `StudentDemoSeed.coachedStudent` (StudentKit). The id matches
  /// `StudentDemoSeed.studentID` so the logged-in user lines up with the seeded
  /// plan/logs/feedback; StudentRootView seeds independently, so only the
  /// `.coachedStudent` role is load-bearing (it routes RootView to the student UI).
  public static let coachedStudent = User(
    id: UUID(uuidString: "02400000-0000-0000-0000-000000000101")!,
    phone: "+15550102400",
    name: "演示学员",
    unitSystem: .metric,
    role: .coachedStudent,
    createdAt: timestamp,
    updatedAt: timestamp
  )

  /// The demo user this build logs in as. `DEMO_USER_STUDENT` (defined by the
  /// MeetPR-DemoStudent scheme) selects the student; otherwise the coach.
  public static var currentUser: User {
    #if DEMO_USER_STUDENT
      coachedStudent
    #else
      coach
    #endif
  }

  private static let timestamp = Date(timeIntervalSince1970: 1_778_371_200)
}
