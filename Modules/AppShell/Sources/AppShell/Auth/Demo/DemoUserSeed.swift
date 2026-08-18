import CoreModels
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public enum DemoUserSeed {
  public static let accessToken = "demo-access-2026-05-10"
  public static let refreshToken = "demo-refresh-2026-05-10"

  public static let coach = User(
    id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
    phone: "13800000000",
    name: AppShellStrings.demoCoach,
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
    // = 02400000-0000-0000-0000-000000000101 (StudentDemoSeed.studentID); tuple form
    // avoids a production-path force unwrap.
    id: UUID(uuid: (0x02, 0x40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01, 0x01)),
    phone: "+15550102400",
    name: AppShellStrings.demoStudent,
    unitSystem: .metric,
    role: .coachedStudent,
    createdAt: timestamp,
    updatedAt: timestamp
  )

  private static let timestamp = Date(timeIntervalSince1970: 1_778_371_200)
}
