import Foundation
import Testing

@testable import CoreModels

private struct PlateFixture {
  let target: Double
  let achieved: Double
  let perSide: [Double]
}

/// Spec 030 §A1 fixture table, copied independently of the implementation.
@Test func plateMathFixtureTable() {
  let fixtures: [PlateFixture] = [
    PlateFixture(target: 20, achieved: 20, perSide: []),
    PlateFixture(target: 22.5, achieved: 22.5, perSide: [1.25]),
    PlateFixture(target: 25, achieved: 25, perSide: [2.5]),
    PlateFixture(target: 60, achieved: 60, perSide: [20]),
    PlateFixture(target: 62.5, achieved: 62.5, perSide: [20, 1.25]),
    PlateFixture(target: 100, achieved: 100, perSide: [25, 15]),
    PlateFixture(target: 102.5, achieved: 102.5, perSide: [25, 15, 1.25]),
    PlateFixture(target: 107.5, achieved: 107.5, perSide: [25, 15, 2.5, 1.25]),
    PlateFixture(target: 142.5, achieved: 142.5, perSide: [25, 25, 10, 1.25]),
    PlateFixture(target: 170, achieved: 170, perSide: [25, 25, 25]),
    PlateFixture(target: 227.5, achieved: 227.5, perSide: [25, 25, 25, 25, 2.5, 1.25]),
    // Rounding: nearest 2.5 grid, ties away from zero.
    PlateFixture(target: 21, achieved: 20, perSide: []),
    PlateFixture(target: 101.2, achieved: 100, perSide: [25, 15]),
    PlateFixture(target: 101.25, achieved: 102.5, perSide: [25, 15, 1.25]),
  ]
  for fixture in fixtures {
    let loadout = PlateMathCalculator.loadout(forTargetKg: fixture.target)
    #expect(loadout != nil, "target=\(fixture.target)")
    if let loadout {
      #expect(loadout.achievedKg == fixture.achieved, "target=\(fixture.target)")
      #expect(loadout.platesPerSideKg == fixture.perSide, "target=\(fixture.target)")
      #expect(loadout.requestedKg == fixture.target)
    }
  }
}

@Test func belowBarReturnsNil() {
  #expect(PlateMathCalculator.loadout(forTargetKg: 18) == nil)
  #expect(PlateMathCalculator.loadout(forTargetKg: 0) == nil)
  #expect(PlateMathCalculator.loadout(forTargetKg: -100) == nil)
}

@Test func isExactReflectsRounding() {
  #expect(PlateMathCalculator.loadout(forTargetKg: 100)?.isExact == true)
  #expect(PlateMathCalculator.loadout(forTargetKg: 101)?.isExact == false)
}
