import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite struct DashboardProfileNavigationTests {
  @Test(arguments: [false, true])
  func metricCardsRouteToExistingEditors(hasValues: Bool) throws {
    var destination: ProfileCardKind?
    let metrics = DashboardProfileMetrics(
      bodyWeightText: hasValues ? "80 kg" : nil,
      competition: hasValues ? CompetitionCountdown(days: 30, dateText: "2026-11-01") : nil
    )
    let view = DashboardProfileMetricsView(
      metrics: metrics,
      showsCompetitionPlaceholder: true,
      showsBodyWeightPlaceholder: true,
      onEditProfile: { destination = $0 }
    )
    let buttons = try view.inspect().findAll(ViewType.Button.self)
    #expect(buttons.count == 2)
    try buttons[0].tap()
    #expect(destination == .basics)
    try buttons[1].tap()
    #expect(destination == .competition)
  }
}
