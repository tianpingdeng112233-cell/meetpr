import CoreModels
import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func draftSetSpecRoundTripsWeightMode() throws {
  let spec = DraftSetSpec(setCount: 4, targetReps: 5, intensityMode: .weight, targetValue: 142.5)

  let decoded = try MeetPRCodec.decoder.decode(DraftSetSpec.self, from: encodeSetSpec(spec))

  #expect(decoded == spec)
  #expect(decoded.targetValue == 142.5)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func draftSetSpecRoundTripsRPEMode() throws {
  let spec = DraftSetSpec(setCount: 3, targetReps: 8, intensityMode: .rpe, targetValue: 8.5)

  let decoded = try MeetPRCodec.decoder.decode(DraftSetSpec.self, from: encodeSetSpec(spec))

  #expect(decoded.intensityMode == .rpe)
  #expect(decoded.targetValue == 8.5)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func draftSetSpecPreservesNilRepsMax() throws {
  let spec = DraftSetSpec(setCount: 5, targetReps: 3, intensityMode: .weight, targetValue: 120)

  let decoded = try MeetPRCodec.decoder.decode(DraftSetSpec.self, from: encodeSetSpec(spec))

  #expect(decoded.targetRepsMax == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func draftSetSpecPreservesNonNilRepsMax() throws {
  let spec = DraftSetSpec(
    setCount: 3,
    targetReps: 8,
    targetRepsMax: 12,
    intensityMode: .weight,
    targetValue: 60
  )

  let decoded = try MeetPRCodec.decoder.decode(DraftSetSpec.self, from: encodeSetSpec(spec))

  #expect(decoded.targetRepsMax == 12)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func draftSetSpecRoundTripsRestFields() throws {
  let spec = DraftSetSpec(
    setCount: 3,
    targetReps: 5,
    intensityMode: .rpe,
    targetValue: 8,
    restSeconds: 180,
    restSecondsPerSet: [150, 180, 210]
  )

  let decoded = try MeetPRCodec.decoder.decode(DraftSetSpec.self, from: encodeSetSpec(spec))

  #expect(decoded.restSeconds == 180)
  #expect(decoded.restSecondsPerSet == [150, 180, 210])
}
