import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func studentPlanCacheInvalidatesPreZeroBasedProjectionFiles() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "StudentPlanCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let studentID = UUID()
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: Date(timeIntervalSince1970: 1_777_248_000),
    days: []
  )
  let legacyURL = directory.appending(path: "student-\(studentID.uuidString)-plan.json")
  try MeetPRCodec.encoder.encode(plan).write(to: legacyURL)

  let cache = StudentPlanCache(directory: directory)

  #expect(await cache.loadPlan(studentID: studentID) == nil)

  try await cache.save(plan: plan, studentID: studentID)

  #expect(await cache.loadPlan(studentID: studentID) == plan)
  #expect(
    FileManager.default.fileExists(
      atPath:
        directory
        .appending(path: "student-\(studentID.uuidString)-plan-v2.json")
        .path
    )
  )
}
