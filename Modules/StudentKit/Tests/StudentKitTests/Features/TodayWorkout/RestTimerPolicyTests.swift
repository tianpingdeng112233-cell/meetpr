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

@Test func accessoryRestPolicyUsesCoachThenStudentThenSixtySeconds() {
  #expect(RestTimerPolicy.accessorySeconds(coachSeconds: 75, studentSeconds: 90) == 75)
  #expect(RestTimerPolicy.accessorySeconds(coachSeconds: 0, studentSeconds: 90) == 0)
  #expect(RestTimerPolicy.accessorySeconds(coachSeconds: nil, studentSeconds: 90) == 90)
  #expect(RestTimerPolicy.accessorySeconds(coachSeconds: nil, studentSeconds: nil) == 60)
  #expect(RestTimerPolicy.restSeconds(forRPE: 10) == 240)
}
