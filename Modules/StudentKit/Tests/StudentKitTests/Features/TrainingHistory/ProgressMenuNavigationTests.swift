import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Test(arguments: [false, true])
func progressMenuKeepsFourNavigableRowsWithoutChartsWhileUnavailable(failed: Bool) throws {
  var destinations: [ProgressMenuDestination] = []
  let view = ProgressMenuContent(
    values: nil, isFailed: failed, onOpen: { destinations.append($0) }, onRetry: {})
  let rows = try view.inspect().findAll(StudentMenuRow.self)
  #expect(rows.count == 4)
  #expect(
    try rows.map { try $0.actualView().title } == [
      StudentStrings.localized(.progressE1rm), StudentStrings.localized(.e1rmSourceHistory),
      StudentStrings.localized(.feedbackInboxView006), StudentStrings.localized(.progressIntensity),
    ])
  for row in rows {
    #expect(try row.actualView().value == nil)
    try row.find(ViewType.Button.self).tap()
  }
  #expect(destinations == [.e1rm, .history, .feedback, .intensity])
  #expect(try view.inspect().findAll(GrowthE1RMCard.self).isEmpty)
  #expect(try view.inspect().findAll(VolumeIntensityChart.self).isEmpty)
}
