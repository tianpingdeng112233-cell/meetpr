import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncNetworkTests {
  @Test func networkRecoveryBypassesBackoff() async throws {
    let clock = SetSyncTestClock()
    let stream = AsyncStream.makeStream(of: Bool.self)
    let network = SetSyncTestNetwork(updates: stream.stream)
    var delays: [Duration] = []
    var attempts = 0
    let queue = try SetSyncQueue(
      studentID: UUID(), storage: MemorySetSyncStorage(),
      sleep: { delay in
        delays.append(delay)
        await clock.sleep()
      },
      send: { record in
        attempts += 1
        if attempts == 1 { throw URLError(.timedOut) }
        return .planned(record.plannedLog)
      })
    let draft = SetSyncQueueTests.draft()
    let day = UUID()
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: draft)
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: draft)
    #expect(queue.pendingSetCount == 1)
    queue.start(network: network)
    await clock.waitUntilSleeping()
    #expect(delays == [.seconds(2)])
    #expect(queue.pendingCount == 2)
    stream.continuation.yield(true)
    try await waitForSetSync { queue.pendingCount == 0 }
    #expect(attempts == 3)
    queue.stop()
    clock.advance()
    stream.continuation.finish()
  }
}

private struct SetSyncTestNetwork: UploadNetworkMonitoring {
  let updates: AsyncStream<Bool>
}
