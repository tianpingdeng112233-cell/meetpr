import Foundation
import Testing
import ViewInspector

@testable import CoachKit

/// Lock-protected capture box: the onConfirm closure is nonisolated async,
/// so the record must be Sendable-safe.
private final class ConfirmCapture: @unchecked Sendable {
  private let lock = NSLock()
  private var _invocation: (skip: Bool, reason: String?)?

  var invocation: (skip: Bool, reason: String?)? {
    lock.lock()
    defer { lock.unlock() }
    return _invocation
  }

  func record(skip: Bool, reason: String?) {
    lock.lock()
    defer { lock.unlock() }
    _invocation = (skip, reason)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptSheetSealsEvaluationChoice() throws {
  let sut = AcceptBindRequestSheet(studentName: "李四") { _, _ in true }
  let inspected = try sut.inspect()

  // Evaluation sealed for beta (2026-07-13): the two-choice cards and the
  // skip-reason field are gone — the sheet is a plain confirm.
  #expect(throws: (any Error).self) {
    _ = try inspected.find(text: "进入 7 天评估期")
  }
  #expect(throws: (any Error).self) {
    _ = try inspected.find(text: "跳过评估期(熟人)")
  }
  #expect(throws: (any Error).self) {
    _ = try inspected.find(ViewType.TextField.self)
  }
  _ = try inspected.find(text: CoachBindStrings.text("coach.bind.accept.confirm"))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptSheetConfirmAlwaysSendsSkipWithNoReason() async throws {
  // The sealed sheet must hardwire the skip branch: onConfirm(true, nil),
  // never the 7-day evaluation and never a reason.
  let capture = ConfirmCapture()
  let sut = AcceptBindRequestSheet(studentName: "李四") { skip, reason in
    capture.record(skip: skip, reason: reason)
    return true
  }

  try sut.inspect().find(button: CoachBindStrings.text("coach.bind.accept.confirm")).tap()

  // submit() hops through a Task — poll briefly for the closure to land.
  for _ in 0..<200 where capture.invocation == nil {
    try await Task.sleep(for: .milliseconds(5))
  }
  let invocation = try #require(capture.invocation)
  #expect(invocation.skip == true)
  #expect(invocation.reason == nil)
}
