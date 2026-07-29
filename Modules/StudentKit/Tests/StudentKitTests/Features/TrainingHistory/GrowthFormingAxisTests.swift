import Foundation
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

  @Test func chartDateAxisIsMonotonicAndKeepsTheCurrentPointDate() {
    let july20 = Date(timeIntervalSince1970: 1_774_137_600)
    let july25 = july20.addingTimeInterval(5 * 86_400)
    let july26 = july20.addingTimeInterval(6 * 86_400)

    let axis = GrowthChartDateAxis(
      plotDates: [july26, july20, july25],
      currentPointDate: july25
    )

    #expect(axis.startDate == july20)
    #expect(axis.startDate <= axis.middleDate)
    #expect(axis.middleDate <= axis.endDate)
    #expect(axis.endDate == july26)
    #expect(axis.currentPointDate == july25)
  }
}
