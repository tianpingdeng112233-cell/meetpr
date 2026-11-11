import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor @Test func bodyWeightEntrySavesTodayAndOverwritesThroughSharedRepository() async throws {
  let now = try Date("2026-11-10T12:00:00Z", strategy: .iso8601)
  let student = UUID()
  let repo = InMemoryOnboardingRepository(studentId: student, now: { now })
  let model = BodyWeightEntryModel(studentID: student, onboarding: repo)
  #expect(await model.save("77.4"))
  #expect(await model.save("77.1"))
  #expect(try await repo.fetchBodyWeights().count == 1)
  #expect(try await repo.fetchProfile(studentId: student)?.weightKg == Decimal(string: "77.1"))
  #expect(!(await model.save("500")))
  #expect(!(await model.save("0")))
  #expect(!(await model.save("77.12")))
}

@Test func dailyBodyWeightPreferenceDefaultsOffAndIsAccountScoped() throws {
  let name = "spec108-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  let first = UUID()
  let second = UUID()
  #expect(!defaults.bool(forKey: DailyBodyWeightPreference.key(studentID: first)))
  defaults.set(true, forKey: DailyBodyWeightPreference.key(studentID: first))
  #expect(defaults.bool(forKey: DailyBodyWeightPreference.key(studentID: first)))
  #expect(!defaults.bool(forKey: DailyBodyWeightPreference.key(studentID: second)))
}

@MainActor @Test func bodyWeightEntryKeepsLoadedProfileWhenRefreshFails() async {
  let repository = ScriptedOnboardingRepository()
  repository.fetchResult = OnboardingFixtures.serverProfile()
  let model = BodyWeightEntryModel(studentID: OnboardingFixtures.studentId, onboarding: repository)
  await model.load()
  let loaded = model.profile
  repository.fetchError = BodyWeightError.unavailable
  await model.load()
  #expect(model.profile == loaded)
  #expect(model.profile != nil)
}

@MainActor @Test func existingBodyWeightOpensWithAValidSingleDecimal() {
  let text = BodyWeightEntryModel.inputText(Decimal(string: "77.40"))
  #expect(text == "77.4")
  #expect(BodyWeightEntryModel.kilograms(text) == Decimal(string: "77.4"))
  #expect(BodyWeightEntryModel.inputText(nil).isEmpty)
}
