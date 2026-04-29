import CoreModels
import Foundation

public struct DayLiftAssignment: Equatable, Hashable, Sendable {
  public let dayOfWeek: Int
  public var liftFamilies: Set<LiftFamily>

  public init(dayOfWeek: Int, liftFamilies: Set<LiftFamily> = []) {
    self.dayOfWeek = dayOfWeek
    self.liftFamilies = liftFamilies
  }
}
