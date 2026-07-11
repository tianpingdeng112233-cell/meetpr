import Foundation
import Testing

@testable import CoreModels

@Test func e1rmHistoryPointRoundTrips() throws {
  let point = E1RMHistoryPoint(
    id: UUID(),
    studentId: UUID(),
    exerciseId: UUID(),
    setLogId: UUID(),
    computedAt: Date(timeIntervalSince1970: 1_768_262_400),
    e1RMKg: 128.2,
    sourceWeightKg: 100,
    sourceReps: 5,
    sourceRPE: 8.0
  )
  let data = try JSONEncoder().encode(point)
  let decoded = try JSONDecoder().decode(E1RMHistoryPoint.self, from: data)
  #expect(decoded == point)
}

@Test func e1rmHistoryPointRoundTripsWithNilRPE() throws {
  let point = E1RMHistoryPoint(
    id: UUID(),
    studentId: UUID(),
    exerciseId: UUID(),
    setLogId: UUID(),
    computedAt: Date(timeIntervalSince1970: 1_768_262_400),
    e1RMKg: 116.7,
    sourceWeightKg: 100,
    sourceReps: 5,
    sourceRPE: nil
  )
  let data = try JSONEncoder().encode(point)
  let decoded = try JSONDecoder().decode(E1RMHistoryPoint.self, from: data)
  #expect(decoded == point)
  #expect(decoded.sourceRPE == nil)
}

@Test func prBreakthroughEventRoundTripsAndAcknowledges() throws {
  let event = PRBreakthroughEvent(
    id: UUID(),
    studentId: UUID(),
    exerciseId: UUID(),
    pointId: UUID(),
    breakthroughE1RMKg: 137.6,
    previousMaxE1RMKg: 135.2,
    occurredAt: Date(timeIntervalSince1970: 1_768_262_400),
    acknowledgedAt: nil
  )
  let data = try JSONEncoder().encode(event)
  let decoded = try JSONDecoder().decode(PRBreakthroughEvent.self, from: data)
  #expect(decoded == event)

  let ackDate = Date(timeIntervalSince1970: 1_768_348_800)
  let acked = event.acknowledged(at: ackDate)
  #expect(acked.acknowledgedAt == ackDate)
  #expect(acked.id == event.id)
  #expect(acked.breakthroughE1RMKg == event.breakthroughE1RMKg)
}

@Test func e1rmHistoryPointDecodesLegacyJSONWithoutConfidenceAsNormal() throws {
  let point = E1RMHistoryPoint(
    id: UUID(),
    studentId: UUID(),
    exerciseId: UUID(),
    setLogId: UUID(),
    computedAt: Date(timeIntervalSince1970: 1_768_262_400),
    e1RMKg: 128.2,
    sourceWeightKg: 100,
    sourceReps: 5,
    sourceRPE: 8.0
  )
  let data = try JSONEncoder().encode(point)
  var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  object.removeValue(forKey: "confidence")
  let legacyData = try JSONSerialization.data(withJSONObject: object)

  let decoded = try JSONDecoder().decode(E1RMHistoryPoint.self, from: legacyData)

  #expect(decoded.confidence == .normal)
}

@Test func e1rmHistoryPointPreservesLowConfidenceAcrossRoundTrip() throws {
  let point = E1RMHistoryPoint(
    id: UUID(),
    studentId: UUID(),
    exerciseId: UUID(),
    setLogId: UUID(),
    computedAt: Date(timeIntervalSince1970: 1_768_262_400),
    e1RMKg: 327,
    sourceWeightKg: 275,
    sourceReps: 3,
    sourceRPE: 8.5,
    confidence: .low
  )

  let data = try JSONEncoder().encode(point)
  let decoded = try JSONDecoder().decode(E1RMHistoryPoint.self, from: data)

  #expect(decoded == point)
  #expect(decoded.confidence == .low)
}
