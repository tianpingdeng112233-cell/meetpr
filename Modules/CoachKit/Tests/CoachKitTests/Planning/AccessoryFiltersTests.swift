import CoreModels
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryFiltersEmptyStaticHasNoFacetSelections() {
  let filters = AccessoryFilters.empty

  #expect(filters.isEmpty)
  #expect(filters.muscleGroups.isEmpty)
  #expect(filters.equipment.isEmpty)
  #expect(filters.movementPatterns.isEmpty)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryFiltersIsEmptyTracksAnySelectedFacet() {
  var filters = AccessoryFilters.empty
  #expect(filters.isEmpty)

  filters.equipment = [.barbell]

  #expect(!filters.isEmpty)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryFiltersAreEquatableAndHashable() {
  let filters = AccessoryFilters(
    muscleGroups: [.quad, .glute],
    equipment: [.barbell],
    movementPatterns: [.push]
  )
  let set: Set<AccessoryFilters> = [filters]

  #expect(set.contains(filters))
  #expect(
    filters
      == AccessoryFilters(
        muscleGroups: [.quad, .glute],
        equipment: [.barbell],
        movementPatterns: [.push]
      ))
}
