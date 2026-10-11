import Testing

@testable import StudentKit

@Test func spec085MeetClassRoundTripsAndRejectsLegacyValues() throws {
  for value in ["IPF · 120+ kg", "IPL · 67.5 kg", "CPA · 100+ kg"] {
    let parsed = try #require(MeetClass.parse(value))
    #expect(parsed.formatted == value)
  }
  for value in ["83kg", "-93", "IPF", "IPF · 82.5 kg", "XYZ · 83 kg"] {
    #expect(MeetClass.parse(value) == nil)
  }
}

@Test func spec085MeetTablesMatchApprovedOpenClasses() {
  let expected: [MeetFederation: [String]] = [
    .ipf: ["59 66 74 83 93 105 120 120+", "47 52 57 63 69 76 84 84+"],
    .worldPowerlifting: ["62 69 77 85 94 105 120 120+", "48 53 58 64 72 84 100 100+"],
    .ipl: [
      "52 56 60 67.5 75 82.5 90 100 110 125 140 140+",
      "44 48 52 56 60 67.5 75 82.5 90 100 110 110+",
    ],
    .cpa: [
      "52 56 60 67.5 75 82.5 90 100 110 125 140 140+",
      "44 48 52 56 60 67.5 75 82.5 90 100 100+",
    ],
  ]
  for (federation, table) in expected {
    #expect(federation.classes(for: .male) == table[0].split(separator: " ").map(String.init))
    #expect(federation.classes(for: .female) == table[1].split(separator: " ").map(String.init))
  }
}
