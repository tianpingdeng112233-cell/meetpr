import Foundation
import Testing

@testable import CoreModels

private let day0 = Date(timeIntervalSince1970: 1_777_248_000)  // midnight UTC
private func at(_ weeks: Int) -> Date {
  day0.addingTimeInterval(Double(weeks) * 7 * 86_400)
}
private func pt(_ weeks: Int, _ e1RMKg: Double) -> E1RMPlateauDetector.Point {
  .init(date: at(weeks), e1RMKg: e1RMKg)
}

@Test func plateauRisingNeverPlateaus() {
  let result = E1RMPlateauDetector.detect(
    points: [pt(0, 160), pt(1, 165), pt(2, 170), pt(3, 175), pt(4, 180), pt(5, 185)])
  #expect(!result.isPlateau)
  #expect(result.weeksStalled == 0)
  #expect(result.bestE1RMKg == 185)
  #expect(result.lastGainAt == at(5))
}

@Test func plateauFlatIsPlateau() {
  let result = E1RMPlateauDetector.detect(
    points: [pt(0, 180), pt(1, 180), pt(2, 180), pt(3, 180), pt(4, 180), pt(5, 180)])
  #expect(result.isPlateau)
  #expect(result.weeksStalled == 5)
  #expect(result.bestE1RMKg == 180)
  #expect(result.lastGainAt == at(0))
}

@Test func plateauSubThresholdCreepIsPlateau() {
  // Every gain < 2.5kg ⇒ no meaningful improvement ⇒ plateau; best = running max.
  let result = E1RMPlateauDetector.detect(
    points: [pt(0, 180), pt(1, 181), pt(2, 181.5), pt(3, 182), pt(4, 182.4)])
  #expect(result.isPlateau)
  #expect(result.bestE1RMKg == 182.4)
  #expect(result.lastGainAt == at(0))
  #expect(result.weeksStalled == 4)
}

@Test func plateauRecentMeaningfulGainResetsStall() {
  // Flat weeks 0-4, then a +5 jump at week 5 ⇒ not a plateau, stall resets.
  let result = E1RMPlateauDetector.detect(
    points: [pt(0, 180), pt(1, 180), pt(2, 180), pt(3, 180), pt(4, 180), pt(5, 185)])
  #expect(!result.isPlateau)
  #expect(result.weeksStalled == 0)
  #expect(result.lastGainAt == at(5))
}

@Test func plateauInsufficientDataIsNeverPlateau() {
  // Far apart but only 2 points (< minPoints) ⇒ not a plateau.
  let result = E1RMPlateauDetector.detect(points: [pt(0, 180), pt(8, 180)])
  #expect(!result.isPlateau)
}

@Test func plateauStallBoundaryAtFourWeeks() {
  let four = E1RMPlateauDetector.detect(
    points: [pt(0, 180), pt(1, 180), pt(2, 180), pt(4, 180)])
  #expect(four.weeksStalled == 4)
  #expect(four.isPlateau)

  let three = E1RMPlateauDetector.detect(
    points: [pt(0, 180), pt(1, 180), pt(2, 180), pt(3, 180)])
  #expect(three.weeksStalled == 3)
  #expect(!three.isPlateau)
}

@Test func plateauEmptyIsNone() {
  #expect(E1RMPlateauDetector.detect(points: []) == .none)
}

@Test func plateauUnsortedInputHandled() {
  let result = E1RMPlateauDetector.detect(
    points: [pt(5, 180), pt(0, 180), pt(3, 180), pt(1, 180)])
  #expect(result.weeksStalled == 5)
  #expect(result.isPlateau)
}
