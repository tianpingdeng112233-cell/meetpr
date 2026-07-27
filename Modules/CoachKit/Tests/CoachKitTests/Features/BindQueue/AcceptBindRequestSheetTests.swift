import Foundation
import Testing
import ViewInspector

@testable import CoachKit

/// Lock-protected capture box: the onConfirm closure is nonisolated async,
/// so the record must be Sendable-safe.
private final class ConfirmCapture: @unchecked Sendable {
  private let lock = NSLock()
  private var _wasInvoked = false

  var wasInvoked: Bool {
    lock.lock()
    defer { lock.unlock() }
    return _wasInvoked
  }

  func recordInvocation() {
    lock.lock()
    defer { lock.unlock() }
    _wasInvoked = true
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptSheetShowsPlainConfirmation() throws {
  let sut = AcceptBindRequestSheet(studentName: "李四") { true }
  let inspected = try sut.inspect()

  #expect(throws: (any Error).self) {
    _ = try inspected.find(ViewType.TextField.self)
  }
  _ = try inspected.find(text: "确认接收")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func acceptSheetConfirmInvokesAction() async throws {
  let capture = ConfirmCapture()
  let sut = AcceptBindRequestSheet(studentName: "李四") {
    capture.recordInvocation()
    return true
  }

  try sut.inspect().find(button: "确认接收").tap()

  // submit() hops through a Task — poll briefly for the closure to land.
  for _ in 0..<200 where !capture.wasInvoked {
    try await Task.sleep(for: .milliseconds(5))
  }
  #expect(capture.wasInvoked)
}
