import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncLogoutTests {
  @Test func logoutCountIsInterpolatedInEveryLanguage() {
    let expected = [
      "zh-Hans": "还有 5 组没上传",
      "en": "5 sets haven't uploaded yet",
      "zh-Hant": "還有 5 組沒上傳",
    ]
    for (language, title) in expected {
      #expect(
        StudentStrings.replacing(
          .setSyncLogoutMany, values: ["5"], locale: Locale(identifier: language))
          == title)
    }
  }

  @Test func directLogoutRetainsAccountQueue() async throws {
    let student = UUID()
    let storage = MemorySetSyncStorage()
    let queue = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    try queue.enqueue(dayID: UUID(), trainingDate: Date(), draft: SetSyncQueueTests.draft())
    var logouts = 0
    let session = StudentSetSyncSession(
      queue: queue,
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [:])),
      onLogout: { logouts += 1 })
    await session.requestLogout()
    #expect(session.showsLogout)
    #expect(logouts == 0)
    await session.logOutNow()
    #expect(logouts == 1)
    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    #expect(restored.pendingCount == 1)
  }

  @Test func uploadThenLogoutAndCancel() async throws {
    var available = false
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) { record in
      guard available else { throw URLError(.notConnectedToInternet) }
      return .planned(record.plannedLog)
    }
    try queue.enqueue(dayID: UUID(), trainingDate: Date(), draft: SetSyncQueueTests.draft())
    var logouts = 0
    let session = StudentSetSyncSession(
      queue: queue,
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [:])),
      onLogout: { logouts += 1 })
    await session.requestLogout()
    session.uploadThenLogout()
    #expect(session.isUploadingForLogout)
    session.cancelLogout()
    #expect(!session.isUploadingForLogout)
    #expect(!session.showsLogout)
    #expect(logouts == 0)
    available = true
    await session.requestLogout()
    session.uploadThenLogout()
    try await waitForSetSync { logouts == 1 }
    #expect(queue.pendingCount == 0)
  }
}
