import Testing

@testable import StudentKit

@Suite struct GrowthFormingAxisTests {
  @Test func trustedAnchorYieldsRoundedTriplet() {
    #expect(GrowthFormingAxis.labelValues(anchorKg: 187.5) == [200, 190, 180])
  }

  @Test func lowConfidenceOnlyHistoryHasNoFabricatedScale() {
    // Only low-confidence imports → no trusted anchor → no numeric labels;
    // the old code fabricated a 160/150/140 axis here.
    #expect(GrowthFormingAxis.labelValues(anchorKg: nil) == nil)
  }
}
