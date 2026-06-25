import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptSheetDefaultsToSkippingEvaluation() throws {
  let sut = AcceptBindRequestSheet(studentName: "李四") { _, _ in true }
  let inspected = try sut.inspect()

  // Beta has no evaluation period, so the sheet defaults to the skip branch —
  // the optional skip-reason field is revealed on first render.
  _ = try inspected.find(ViewType.TextField.self)
}
