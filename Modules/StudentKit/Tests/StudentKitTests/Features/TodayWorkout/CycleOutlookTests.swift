import Foundation
import Testing

@testable import StudentKit

struct CycleOutlookTests {
  struct Fixture: Decodable { let cases: [Case] }
  struct Case: Decodable {
    let name: String
    let currentWeekIndex: Int
    let lifts: [Lift]
  }
  struct Lift: Decodable {
    let input: Input
    let expected: [Expected]
  }
  struct Input: Decodable {
    let e1rmKg: Double?
    let oneRmKg: Double?
    let weeks: [CycleOutlookWeek]
  }
  struct Expected: Decodable {
    let state: String
    let isCurrent: Bool
    let done: Bool?
    let short: Bool?
    let skipped: Bool?
    let main: String?
    let sub: String?
    let ratio: Double?
    let isTop: Bool?
  }
  static func fixtures() throws -> [Case] {
    let url = try #require(
      Bundle.module.url(
        forResource: "cycle-outlook-cases", withExtension: "json", subdirectory: "CycleOutlook"))
    return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url)).cases
  }

  @Test(arguments: try fixtures())
  func matchesApprovedReference(fixture: Case) throws {
    for lift in fixture.lifts {
      let cells = CycleOutlook.row(
        weeks: lift.input.weeks, e1RM: lift.input.e1rmKg,
        oneRM: lift.input.oneRmKg, currentWeekIndex: fixture.currentWeekIndex,
        locale: Locale(identifier: "zh-Hans"))
      #expect(cells.count == lift.expected.count)
      for (cell, expected) in zip(cells, lift.expected) {
        #expect(cell.state.rawValue == expected.state)
        #expect(cell.isCurrent == expected.isCurrent)
        #expect(cell.done == (expected.done ?? false))
        #expect(cell.short == (expected.short ?? false))
        #expect(cell.skipped == (expected.skipped ?? false))
        if let main = expected.main { #expect(cell.main == main) }
        if let sub = expected.sub { #expect(cell.sub == sub) }
        if let ratio = expected.ratio { #expect(abs(cell.ratio - ratio) <= 0.01) }
        #expect(cell.isTop == (expected.isTop ?? false))
      }
    }
  }
}
