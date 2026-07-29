import Testing
import ViewInspector

@testable import DesignSystem

@MainActor
@Suite("SetReadOnlyCell")
struct SetReadOnlyCellTests {
  @Test("zero-based first set renders hash one")
  func zeroBasedFirstSetRendersHashOne() throws {
    let inspected = try SetReadOnlyCell(
      setIndex: 0,
      weightKg: nil,
      reps: nil,
      rpe: nil,
      isCompleted: false
    ).inspect()

    #expect(try inspected.find(text: "#1").string() == "#1")
  }
}
