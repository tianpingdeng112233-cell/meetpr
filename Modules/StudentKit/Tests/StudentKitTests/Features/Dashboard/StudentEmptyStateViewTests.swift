import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite("Student empty and failure states")
struct StudentEmptyStateViewTests {
  @Test("account actions remain reachable in profile fallback states")
  func accountActionsRemainReachableInProfileFallbackStates() async throws {
    let emptyRepository = ScriptedOnboardingRepository()
    let emptyViewModel = MyProfileViewModel(studentId: UUID(), repo: emptyRepository)
    await emptyViewModel.reload()

    let failedRepository = ScriptedOnboardingRepository()
    failedRepository.fetchError = EmptyStateViewTestError.failed
    let failedViewModel = MyProfileViewModel(studentId: UUID(), repo: failedRepository)
    await failedViewModel.reload()

    #expect(emptyViewModel.state == .empty)
    #expect(failedViewModel.state == .failed)

    let inspected = try MyProfileFallbackRows(
      studentID: UUID(),
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
      account: InMemoryAccountRepository(),
      logs: InMemoryStudentTrainingLogRepository(),
      restTimerSettings: EmptyStateRestTimerSettingsStore(),
      trainingReminderServices: TrainingReminderServices(
        store: TrainingReminderUserDefaultsStore(
          defaults: try #require(
            UserDefaults(suiteName: "StudentEmptyStateViewTests.\(UUID().uuidString)"))
        ),
        center: FakeTrainingReminderNotificationCenter()
      ),
      onLogout: nil
    ).inspect()

    _ = try inspected.find(viewWithAccessibilityIdentifier: "account.changePassword")
    _ = try inspected.find(viewWithAccessibilityIdentifier: "account.export")
  }

  @Test("volume chart exposes its own insufficient-data state")
  func volumeChartExposesInsufficientDataState() throws {
    let inspected = try VolumeIntensityChart(buckets: [], isUnlocked: false).inspect()

    #expect(
      try inspected.find(text: StudentStrings.localized(.growthEmptyStates001)).string()
        == StudentStrings.localized(.growthEmptyStates001)
    )
  }

}

private enum EmptyStateViewTestError: Error {
  case failed
}

private struct EmptyStateRestTimerSettingsStore: StudentRestTimerSettingsStoring {
  func accessorySeconds(for studentID: UUID) -> Int { 60 }
  func setAccessorySeconds(_ seconds: Int, for studentID: UUID) {}
  func preference(for studentID: UUID) -> StudentRestTimerPreference {
    .automatic
  }

  func setPreference(_ preference: StudentRestTimerPreference, for studentID: UUID) {}

  func hasAcknowledgedExplanation(for studentID: UUID) -> Bool {
    false
  }

  func markExplanationAcknowledged(for studentID: UUID) {}
}
