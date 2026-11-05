import DesignSystem
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@Suite @MainActor struct SetSyncControlTests {
  @Test func failedControlUsesOrange() async throws {
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) { _ in
      throw SetSyncFailure.rejected
    }
    let day = UUID()
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: SetSyncQueueTests.draft())
    await queue.drain()
    let coordinator = SetSyncCompletionCoordinator(queue: queue)
    #expect(!(await coordinator.prepare(dayID: day)))
    let view = SetSyncCompletionControl(coordinator: coordinator, onComplete: {})
    let inspected = try view.inspect()
    #expect(
      try inspected.find(ViewType.HStack.self).foregroundStyleShapeStyle(Color.self)
        == Color.MeetPR.failure)
    #expect(
      try inspected.find(text: StudentStrings.localized(.setSyncFailedBody)).string().isEmpty
        == false)
  }

  @Test func syncingUsesWhiteTrainingButtonForeground() async throws {
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let day = UUID()
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: SetSyncQueueTests.draft())
    let clock = SetSyncTestClock()
    let coordinator = SetSyncCompletionCoordinator(queue: queue, sleep: { await clock.sleep() })
    let waiting = Task { await coordinator.prepare(dayID: day) }
    await clock.waitUntilSleeping()
    let view = SetSyncCompletionControl(coordinator: coordinator, onComplete: {})
    let stack = try view.inspect().find(ViewType.HStack.self)
    #expect(try stack.foregroundStyleShapeStyle(Color.self) == Color.MeetPR.inkOnCTAFill)
    #expect(try stack.find(ViewType.ProgressView.self).tint() == Color.MeetPR.inkOnCTAFill)
    coordinator.reset()
    clock.advance()
    _ = await waiting.value
  }
}
