import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func parseWeightRejectsZodOutOfBounds() {
  #expect(UnitDisplay.parseWeight("0", unit: .kg) == nil)
  #expect(UnitDisplay.parseWeight("500", unit: .kg) == nil)
  #expect(UnitDisplay.parseWeight("83", unit: .kg) == 83)
  // 1200 lb ≈ 544 kg — legal-looking imperial input crossing the metric bound.
  #expect(UnitDisplay.parseWeight("1200", unit: .lb) == nil)
}

@Test func parseHeightRejectsZodOutOfBounds() {
  #expect(UnitDisplay.parseHeight("0", unit: .kg) == nil)
  #expect(UnitDisplay.parseHeight("300", unit: .kg) == nil)
  #expect(UnitDisplay.parseHeight("178", unit: .kg) == 178)
  // 130 in ≈ 330 cm — out of bounds after conversion.
  #expect(UnitDisplay.parseHeight("130", unit: .lb) == nil)
}
