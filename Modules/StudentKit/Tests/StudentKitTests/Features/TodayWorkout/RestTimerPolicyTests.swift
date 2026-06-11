import Foundation
import Testing

@testable import StudentKit

/// Spec 030 §B1: nil→3min, ≤6.5→2min, 7–8.5→3min, 9+→4min.
@Test func restTimerPolicyMapsRPEPerSpecTable() {
  #expect(RestTimerPolicy.restSeconds(forRPE: nil) == 180)
  #expect(RestTimerPolicy.restSeconds(forRPE: 5) == 120)
  #expect(RestTimerPolicy.restSeconds(forRPE: 6.5) == 120)
  #expect(RestTimerPolicy.restSeconds(forRPE: 7) == 180)
  #expect(RestTimerPolicy.restSeconds(forRPE: 7.5) == 180)
  #expect(RestTimerPolicy.restSeconds(forRPE: 8) == 180)
  #expect(RestTimerPolicy.restSeconds(forRPE: 8.5) == 180)
  #expect(RestTimerPolicy.restSeconds(forRPE: 9) == 240)
  #expect(RestTimerPolicy.restSeconds(forRPE: 10) == 240)
}
