import Foundation
import Testing

@testable import StudentKit

@Suite struct RestTimerExplanationPresentationTests {
  @Test func explanationFormatsDefaultsAndFollowsAnUpdatedRule() {
    let standard = RestTimerExplanationPresentation()
    #expect(standard.rows.map(\.seconds) == [120, 180, 240])
    #expect(standard.rows.map(\.duration) == ["2:00", "3:00", "4:00"])
    let revised = RestTimerExplanationPresentation { rpe in
      if rpe < 7 { return 90 }
      if rpe < 9 { return 150 }
      return 210
    }
    #expect(revised.rows.map(\.duration) == ["1:30", "2:30", "3:30"])
  }
}
