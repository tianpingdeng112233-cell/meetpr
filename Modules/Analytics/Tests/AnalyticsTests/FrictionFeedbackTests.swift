import Foundation
import Testing

@testable import Analytics

@Test @MainActor func reEditRequiresCountOfAtLeastTwo() async throws {
  let harness = try FrictionHarness()

  harness.controller.recordReEdit(
    flow: .recordSet, field: .weight, count: 1, fromScreen: .todayWorkout)
  await settleFrictionTask()

  #expect(harness.controller.pendingPrompt == nil)
  #expect(harness.trackedEvents.isEmpty)
}

@Test @MainActor func frictionPromptAppearsOnlyOncePerSession() async throws {
  let harness = try FrictionHarness()

  harness.controller.recordFlowCancel(flow: .recordSet, fromScreen: .todayWorkout)
  await settleFrictionTask()
  #expect(harness.controller.pendingPrompt != nil)
  harness.controller.send(text: "第一条")

  harness.controller.recordFlowCancel(flow: .recordSet, fromScreen: .todayWorkout)
  await settleFrictionTask()
  #expect(harness.controller.pendingPrompt == nil)
  #expect(harness.prepareCount == 1)
}

@Test @MainActor func skippingStartsCooldownAndDoesNotSubmitText() async throws {
  let clock = TestClock(Date())
  let harness = try FrictionHarness(now: { clock.now() })

  harness.controller.recordFlowCancel(flow: .bind, fromScreen: .bindEnterCode)
  await settleFrictionTask()
  harness.controller.skip()
  harness.controller.beginSession()
  harness.controller.recordFlowCancel(flow: .bind, fromScreen: .bindEnterCode)
  await settleFrictionTask()

  #expect(harness.controller.pendingPrompt == nil)
  #expect(harness.prepareCount == 1)
  #expect(harness.submissions.isEmpty)
}

@Test @MainActor func unavailableAnalyticsSuppressesFrictionPrompt() async throws {
  let harness = try FrictionHarness(prepareEnabled: false)

  harness.controller.recordFlowCancel(flow: .onboarding, fromScreen: .onboardingWizard)
  await settleFrictionTask()

  #expect(harness.controller.pendingPrompt == nil)
}

@Test @MainActor func submittedTextUsesSignalEventIdentifier() async throws {
  let eventID = UUID()
  let harness = try FrictionHarness(eventID: eventID)

  harness.controller.recordFlowCancel(flow: .planning, fromScreen: .coachPlanning)
  await settleFrictionTask()
  harness.controller.send(text: "步骤不好找")

  #expect(harness.submissions.map(\.eventID) == [eventID])
  #expect(harness.submissions.map(\.text) == ["步骤不好找"])
}

@MainActor
private final class FrictionHarness {
  private let recorder: FrictionRecorder
  let controller: FrictionFeedbackController

  var trackedEvents: [AnalyticsEvent] { recorder.trackedEvents }
  var prepareCount: Int { recorder.prepareCount }
  var submissions: [FrictionRecorder.Submission] { recorder.submissions }

  init(
    eventID: UUID = UUID(),
    prepareEnabled: Bool = true,
    now: @escaping @MainActor () -> Date = { Date() }
  ) throws {
    let suiteName = "AnalyticsFrictionTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let recorder = FrictionRecorder()
    self.recorder = recorder
    controller = FrictionFeedbackController(
      defaults: defaults,
      now: now,
      track: { event, _ in recorder.trackedEvents.append(event) },
      prepare: { _, _, _ in
        recorder.prepareCount += 1
        guard prepareEnabled else { return nil }
        return FrictionFeedbackContext(
          eventID: eventID, anonID: UUID(), sessionID: UUID())
      },
      submit: { identifier, _, _, _, text in
        recorder.submissions.append(
          FrictionRecorder.Submission(eventID: identifier, text: text))
      })
  }
}

@MainActor
private final class FrictionRecorder {
  struct Submission {
    let eventID: UUID
    let text: String
  }

  var trackedEvents: [AnalyticsEvent] = []
  var prepareCount = 0
  var submissions: [Submission] = []
}

@MainActor
private func settleFrictionTask() async {
  for _ in 0..<10 {
    await Task.yield()
  }
}
