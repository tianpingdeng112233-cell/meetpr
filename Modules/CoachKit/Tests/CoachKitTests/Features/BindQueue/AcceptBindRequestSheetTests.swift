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
@Test func acceptSheetShowsPlainConfirmation() throws {
  let sut = AcceptBindRequestSheet(studentName: "李四") { _, _ in true }
  let inspected = try sut.inspect()

  #expect(throws: (any Error).self) {
    _ = try inspected.find(ViewType.TextField.self)
  }
  _ = try inspected.find(text: "确认接收")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptSheetConfirmAlwaysSendsSkipWithNoReason() async throws {
  // The sheet keeps the wire-compatible skip branch with no reason.
  let capture = ConfirmCapture()
  let sut = AcceptBindRequestSheet(studentName: "李四") { skip, reason in
    capture.record(skip: skip, reason: reason)
    return true
  }

  try sut.inspect().find(button: "确认接收").tap()

  // submit() hops through a Task — poll briefly for the closure to land.
  for _ in 0..<200 where capture.invocation == nil {
    try await Task.sleep(for: .milliseconds(5))
  }
  let invocation = try #require(capture.invocation)
  #expect(invocation.skip == true)
  #expect(invocation.reason == nil)
}
