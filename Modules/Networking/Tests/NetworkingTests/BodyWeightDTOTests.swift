import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func bodyWeightWireRecordsDecodeDecimalStringsAndCalendarDates() throws {
  let data = Data(#"{"records":[{"recorded_on":"2026-10-09","weight_kg":"83.25"}]}"#.utf8)
  let response = try MeetPRCodec.decoder.decode(BodyWeightRecordsDTO.self, from: data)
  #expect(response.records.first?.recordedOn == "2026-10-09")
  #expect(response.records.first?.weightKg == Decimal(string: "83.25"))
}

@Test func bodyWeightMutationDecodesCurrentWeightAndDeletionNull() throws {
  let saved = Data(
    #"{"record":{"recorded_on":"2026-10-09","weight_kg":"83.25"},"current_weight_kg":"84.00"}"#.utf8
  )
  let response = try MeetPRCodec.decoder.decode(BodyWeightWriteDTO.self, from: saved)
  #expect(response.record.weightKg == Decimal(string: "83.25"))
  #expect(response.currentWeightKg == 84)
  let removed = Data(#"{"current_weight_kg":null}"#.utf8)
  #expect(
    try MeetPRCodec.decoder.decode(BodyWeightDeleteDTO.self, from: removed).currentWeightKg == nil)
}
