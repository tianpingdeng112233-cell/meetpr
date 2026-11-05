import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct OfflineAccessoryTests {
  @Test func pendingAccessoryKeepsEditedWeightAndCanCancelBeforeVideoHydration() async throws {
    let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
    let queue = try SetSyncQueue(
      studentID: StudentDemoSeed.studentID,
      storage: MemorySetSyncStorage()
    ) { _ in throw URLError(.notConnectedToInternet) }
    fixture.model.connectSetSync(queue)
    fixture.model.accessoryVideosLoaded = false
    var row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first),
      previous: nil, unit: .kg)
    row.input.weight = "70"
    #expect(await fixture.model.saveAccessoryRow(row))
    let pending = try #require(fixture.model.currentDrafts?.first)
    let rebuilt = AccessoryRow(draft: pending, previous: nil, unit: .kg)
    #expect(rebuilt.input.weight == "70")
    #expect(await fixture.model.saveAccessoryRow(rebuilt))
    #expect(fixture.model.currentDrafts?.first?.completed == false)
    #expect(fixture.model.actionErrorMessage == nil)
    #expect(queue.pendingCount == 2)
  }
}
