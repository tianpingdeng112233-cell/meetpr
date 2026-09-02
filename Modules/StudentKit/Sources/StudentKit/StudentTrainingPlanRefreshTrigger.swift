import SwiftUI

struct StudentTrainingPlanRefreshTrigger: Equatable, Sendable {
  private(set) var revision = 0

  mutating func handleScenePhase(_ phase: ScenePhase) {
    guard phase == .active else { return }
    revision += 1
  }

  mutating func handleTabSelection(_ tab: StudentTab) {
    guard tab == .training else { return }
    revision += 1
  }
}
