import DesignSystem
import SwiftUI
import Testing

@testable import StudentKit

@Test func timelineConnectorReachesTheNextNodeAcrossCollapsedAndExpandedRows() {
  for height: CGFloat in [48, 76, 280] {
    let path = AllDayTimelineConnector().path(in: CGRect(x: 0, y: 0, width: 22, height: height))
    #expect(path.boundingRect.minX == 11)
    #expect(path.boundingRect.minY == 19)
    #expect(path.boundingRect.maxY == height + MeetPRSpacing.space4 + 19)
  }
}
