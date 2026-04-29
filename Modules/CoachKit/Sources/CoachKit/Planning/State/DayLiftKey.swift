import CoreModels
import Foundation

public struct DayLiftKey: Codable, Equatable, Hashable, Sendable {
  public let dayOfWeek: Int
  public let liftFamily: LiftFamily

  public init(dayOfWeek: Int, liftFamily: LiftFamily) {
    self.dayOfWeek = dayOfWeek
    self.liftFamily = liftFamily
  }
}
