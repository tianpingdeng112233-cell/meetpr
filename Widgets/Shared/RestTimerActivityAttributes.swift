import ActivityKit
import Foundation

struct RestTimerActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let endsAt: Date
    let totalSeconds: Int
  }
}
