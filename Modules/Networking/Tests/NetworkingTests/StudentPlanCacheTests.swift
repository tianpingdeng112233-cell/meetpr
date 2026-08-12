import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func studentPlanCacheInvalidatesPreSequenceProjectionFiles() async throws {
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
  let legacyURL = directory.appending(path: "student-\(studentID.uuidString)-plan-v2.json")
  try MeetPRCodec.encoder.encode(plan).write(to: legacyURL)

  let cache = StudentPlanCache(directory: directory)

  #expect(await cache.loadPlan(studentID: studentID) == nil)

  try await cache.save(plan: plan, studentID: studentID)

  #expect(await cache.loadPlan(studentID: studentID) == plan)
  #expect(
    FileManager.default.fileExists(
      atPath:
        directory
        .appending(path: "student-\(studentID.uuidString)-plan-v3.json")
        .path
    )
  )
}

@Test func studentPlanCacheRoundTripsCompletionForOfflineCursor() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "StudentPlanCacheV3Tests-\(UUID().uuidString)", directoryHint: .isDirectory)
  defer { try? FileManager.default.removeItem(at: directory) }
  let studentID = UUID()
  let completedAt = Date(timeIntervalSince1970: 1_900_000_000)
  let first = StudentPlanDay(
    id: UUID(), weekNumber: 1, dayOfWeek: 1, date: completedAt,
    completedAt: completedAt, completionSource: "auto", exercises: []
  )
  let second = StudentPlanDay(
    id: UUID(), weekNumber: 1, dayOfWeek: 2, date: completedAt, exercises: []
  )
  let plan = StudentPlanView(
    cycleID: UUID(), weekIndex: 1, startDate: completedAt,
    publishedAt: completedAt, days: [first, second]
  )
  let cache = StudentPlanCache(directory: directory)

  try await cache.save(plan: plan, studentID: studentID)
  let restored = try #require(await cache.loadPlan(studentID: studentID))

  #expect(restored.publishedAt == completedAt)
  #expect(StudentPlanSequence.cursorDay(in: restored)?.id == second.id)
}

@Test func studentPlanCacheRoundTripsNewIntensityPayload() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(
      path: "StudentPlanIntensityCacheTests-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
  defer { try? FileManager.default.removeItem(at: directory) }
  let studentID = UUID()
  let date = Date(timeIntervalSince1970: 1_900_000_000)
  let exercise = Exercise(
    id: UUID(),
    name: "深蹲",
    exerciseType: .mainLift,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    createdAt: date
  )
  let prescribed = PrescribedSet(
    id: UUID(),
    setIndex: 0,
    weightKg: 170,
    intensity: .rpe(9),
    reps: 5
  )
  let planExercise = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: [prescribed])
  let plan = StudentPlanView(
    cycleID: UUID(), weekIndex: 1, startDate: date,
    days: [StudentPlanDay(id: UUID(), date: date, exercises: [planExercise])]
  )
  let cache = StudentPlanCache(directory: directory)

  try await cache.save(plan: plan, studentID: studentID)
  let restored = try #require(await cache.loadPlan(studentID: studentID))

  #expect(restored == plan)
  #expect(restored.days[0].exercises[0].prescribedSets[0].weightKg == 170)
  #expect(restored.days[0].exercises[0].prescribedSets[0].intensity == .rpe(9))
}
