import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func demoWeightHistoryLoadsSavesOverwritesAndDeletesWithoutFailure() async throws {
  let studentID = StudentDemoSeed.studentID
  let now = Date()
  let repository = InMemoryOnboardingRepository(
    studentId: studentID, seed: StudentDemoSeed.makeOnboardingProfile(studentID: studentID),
    seedRecentBodyWeights: true, now: { now })
  let page = BodyWeightViewModel(studentID: studentID, repository: repository, now: { now })
  let strip = BodyWeightEntryModel(studentID: studentID, onboarding: repository)
  await page.load()
  await strip.load()
  #expect(page.isLoaded && !page.isFailed)
  try #require(page.records.count >= 5)
  let oldest = try #require(Calendar.current.date(byAdding: .day, value: -29, to: now))
  let today = BodyWeightDay.string(from: now)
  #expect(
    page.records.allSatisfy {
      $0.recordedOn >= BodyWeightDay.string(from: oldest) && $0.recordedOn <= today
    })
  #expect(strip.records == page.records)
  let count = page.records.count
  #expect(await strip.save("77.4"))
  #expect(await strip.save("77.6"))
  await page.load()
  #expect(!page.isFailed && !strip.saveFailed)
  #expect(page.records.count == count)
  #expect(page.records.filter { $0.recordedOn == today }.map(\.weightKg) == [77.6])
  #expect(strip.profile?.weightKg == 77.6)
  for record in page.records {
    #expect(await page.delete(record))
  }
  await strip.load()
  #expect(page.isLoaded && !page.isFailed && page.records.isEmpty)
  #expect(strip.records.isEmpty && strip.profile?.weightKg == nil)
  #expect(await strip.save("78.1"))
  await page.load()
  #expect(page.records.map(\.weightKg) == [78.1])
  #expect(!page.isFailed)
}
