import Foundation
import Testing

@testable import CoreModels

@Test func readinessCheckinRoundTripsWithFatigue() throws {
  let checkin = ReadinessCheckin(
    id: UUID(),
    studentId: UUID(),
    checkinDate: "2026-06-11",
    sleepQuality: 4,
    energy: 5,
    mood: 3,
    stress: 2,
    muscleFatigue: [
      MuscleFatigue(muscleGroup: .quad, severity: 3),
      MuscleFatigue(muscleGroup: .core, severity: 1),
    ],
    submittedAt: Date(timeIntervalSince1970: 1_768_262_400)
  )
  let data = try JSONEncoder().encode(checkin)
  let decoded = try JSONDecoder().decode(ReadinessCheckin.self, from: data)
  #expect(decoded == checkin)
  #expect(decoded.checkinDate == "2026-06-11")
  #expect(decoded.energy == 5)
}

@Test func allowedMuscleGroupsAreExactlyEightUniqueCases() {
  let allowed = ReadinessCheckin.allowedMuscleGroups
  #expect(allowed.count == 8)
  #expect(Set(allowed).count == 8)
  // Locked order = chip order on both ends (spec 030 §C1).
  #expect(allowed == [.quad, .hamstring, .glute, .back, .chest, .shoulder, .triceps, .core])
}
