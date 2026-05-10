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

  private static let timestamp = Date(timeIntervalSince1970: 1_778_371_200)
}
