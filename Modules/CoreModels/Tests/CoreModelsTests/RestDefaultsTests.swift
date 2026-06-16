import Foundation
import Testing

@testable import CoreModels

@Test func restDefaultsMapsRPEBoundaries() {
  #expect(RestDefaults.seconds(forRPE: nil) == 180)
  #expect(RestDefaults.seconds(forRPE: 6.5) == 120)
  #expect(RestDefaults.seconds(forRPE: 7) == 180)
  #expect(RestDefaults.seconds(forRPE: 8.5) == 180)
  #expect(RestDefaults.seconds(forRPE: 9) == 240)
}
