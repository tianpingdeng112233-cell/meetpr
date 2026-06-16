import Foundation
import Testing

@testable import StudentKit

/// StudentKit API forwards to CoreModels.RestDefaults.
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
