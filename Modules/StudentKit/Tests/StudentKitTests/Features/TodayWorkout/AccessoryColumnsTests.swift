import CoreModels
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

#if os(macOS)
  import AppKit
#endif

@MainActor
struct AccessoryColumnsTests {
  #if os(macOS)
    @Test func helpHitAreaContainsVisibleBadgeWithoutEnteringToggle() throws {
      let icon = try EffortExplainerButton(kind: .rir, isAccessoryHeader: true)
        .inspect().find(EffortHelpIcon.self)
      let frame = try icon.fixedFrame()
      let offset = try icon.offset()
      let iconSize = NSHostingView(rootView: try icon.actualView()).fittingSize
      #expect(iconSize == CGSize(width: 14, height: 14))
      for tableWidth: CGFloat in [280, 320, 343, 360, 390] {
        let columnWidth = AccessoryColumns().widths(tableWidth)[4]
        let areas = AccessoryEffortHeaderLayout().hitAreas(width: columnWidth)
        let helpHit = areas.help
        let toggleHit = areas.toggle
        #expect(helpHit.size == CGSize(width: frame.width, height: frame.height))
        #expect(helpHit.maxX == columnWidth)
        let visibleBadge = CGRect(
          x: helpHit.midX - iconSize.width / 2 + offset.width,
          y: helpHit.midY - iconSize.height / 2 + offset.height,
          width: iconSize.width, height: iconSize.height)
        #expect(helpHit.contains(visibleBadge))
        #expect(helpHit.intersection(toggleHit).width == 0)
        #expect(visibleBadge.intersection(toggleHit).width == 0)
        #expect(helpHit.height >= 44)
      }
    }
  #endif

  @Test func previousTextUsesRecordedEffortWithoutChangingCopyAction() async throws {
    let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
    let draft = try #require(fixture.model.currentDrafts?.first)
    let cases: [((Int?, Decimal?), String)] = [
      ((2, 8.5), "30×10@2"), ((nil, 8.5), "30×10@8.5"),
      ((nil, nil), "30×10"), ((0, nil), "30×10@0"),
    ]
    for ((rir, rpe), expected) in cases {
      let previous = StudentSetLog(
        id: UUID(), studentID: UUID(), planExerciseID: UUID(), setIndex: 0,
        loggedAt: .distantPast, weightKg: 30, reps: 10, rpe: rpe,
        actualRIR: rir, coachRPE: 9, completed: true)
      let added = StudentAddedSetLog(
        id: UUID(), studentID: UUID(), exerciseID: UUID(), setIndex: 0,
        loggedAt: .distantPast, weightKg: 30, reps: 10, rpe: rpe,
        actualRIR: rir, coachRPE: 9, completed: true)
      var row = AccessoryRow(draft: draft, previous: previous, unit: .kg)
      #expect(row.previousText == expected)
      #expect(
        AccessoryRow(draft: draft, previous: nil, unit: .kg, previousAdded: added)
          .previousText == expected)
      row.input.rpe = "7"
      row.usePrevious()
      #expect(row.input.weight == "30" && row.input.reps == "10" && row.input.rpe == "7")
    }
    #expect(AccessoryRow(draft: draft, previous: nil, unit: .kg).previousText == "—")
    let previous = StudentSetLog(
      id: UUID(), studentID: UUID(), planExerciseID: UUID(), setIndex: 0,
      loggedAt: .distantPast, weightKg: 102.5, reps: 10, rpe: 8.5, completed: true)
    #expect(
      AccessoryRow(draft: draft, previous: previous, unit: .kg).previousText == "102.5×10@8.5")
    #expect(AccessoryRow(draft: draft, previous: previous, unit: .lb).previousText == "226×10@8.5")
  }

  @Test func effortMatchesRepsAndFreedWidthGoesToPrevious() {
    // At 343pt: 328 usable points. Keep set/KG/reps/done at 36/64/44/40.
    let widths = AccessoryColumns().widths(343)
    #expect(widths == [36, 100, 64, 44, 44, 40])
    for width: CGFloat in [280, 320, 343, 360, 390] {
      let columns = AccessoryColumns().widths(width)
      #expect(columns[4] == columns[3])
      #expect(columns[4] < 88)
      #expect(abs(columns.reduce(0, +) + 15 - width) < 0.001)
    }
  }
}
