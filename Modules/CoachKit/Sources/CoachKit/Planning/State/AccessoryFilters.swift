import CoreModels
import Foundation

public struct AccessoryFilters: Equatable, Hashable, Sendable {
  public var muscleGroups: Set<MuscleGroup>
  public var equipment: Set<Equipment>
  public var movementPatterns: Set<MovementPattern>

  public static let empty = AccessoryFilters()

  public var isEmpty: Bool {
    muscleGroups.isEmpty && equipment.isEmpty && movementPatterns.isEmpty
  }

  public init(
    muscleGroups: Set<MuscleGroup> = [],
    equipment: Set<Equipment> = [],
    movementPatterns: Set<MovementPattern> = []
  ) {
    self.muscleGroups = muscleGroups
    self.equipment = equipment
    self.movementPatterns = movementPatterns
  }
}
