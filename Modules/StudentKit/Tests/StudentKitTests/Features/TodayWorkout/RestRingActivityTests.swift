import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func restRingActivityStartsUpdatesAndEndsThroughControllerSeam() {
  let clock = Date(timeIntervalSince1970: 1000)
  let controller = RingActivitySpy()
  let session = RestRingSession(controller: controller, now: { clock })
  session.start(seconds: 180, exercise: "Bench")
  #expect(controller.events == [.start(clock.addingTimeInterval(180), 180)])
  session.adjust(by: 15)
  #expect(controller.events.last == .update(clock.addingTimeInterval(195), 180))
  session.end()
  #expect(controller.events.last == .end)
  session.start(seconds: 60, exercise: "Row")
  session.completeToday()
  #expect(controller.events.last == .end)
  #expect(session.model.phase == .idle)
}

@MainActor
@Test func backgroundExpiryKeepsNotificationUntilForegroundReturn() {
  let clock = RingTestClock()
  let controller = RingActivitySpy()
  let session = RestRingSession(controller: controller, now: { clock.date })
  session.start(seconds: 30, exercise: "Bench")
  session.setForeground(false)
  clock.date = clock.date.addingTimeInterval(31)
  session.tick()
  #expect(session.model.phase == .done)
  #expect(controller.events.count == 1)
  session.setForeground(true)
  #expect(controller.events.last == .end)
}

@MainActor
@Test func restRingFirstSettingsWaitsForOtherPresentationToClose() {
  let session = RestRingSession(controller: RingActivitySpy())
  session.updatePresentationContext(isTrainable: true, hasOtherPresentation: true)
  #expect(session.presentation == nil)
  #expect(session.settings.needsFirstSettings)
  session.updatePresentationContext(isTrainable: true, hasOtherPresentation: false)
  #expect(session.presentation == .settings)
  session.dismiss()
  #expect(!session.settings.needsFirstSettings)
  session.updatePresentationContext(isTrainable: true, hasOtherPresentation: false)
  #expect(session.presentation == nil)
}

@MainActor
@Test func restRingDefersUnfinishedSetupWhenTrainingLosesPresentationPriority() {
  let session = RestRingSession(controller: RingActivitySpy())
  session.updatePresentationContext(isTrainable: true, hasOtherPresentation: false)
  #expect(session.presentation == .settings)
  session.updatePresentationContext(isTrainable: true, hasOtherPresentation: true)
  #expect(session.presentation == nil)
  #expect(session.settings.needsFirstSettings)
  session.updatePresentationContext(isTrainable: false, hasOtherPresentation: false)
  #expect(session.presentation == nil)
  session.updatePresentationContext(isTrainable: true, hasOtherPresentation: false)
  #expect(session.presentation == .settings)
}

@MainActor
private final class RingTestClock {
  var date = Date(timeIntervalSince1970: 1000)
}

@MainActor
private final class RingActivitySpy: RestTimerActivityControlling {
  enum Event: Equatable {
    case start(Date, Int)
    case update(Date, Int)
    case end
  }
  var events: [Event] = []
  func start(endsAt: Date, totalSeconds: Int) { events.append(.start(endsAt, totalSeconds)) }
  func update(endsAt: Date, totalSeconds: Int) { events.append(.update(endsAt, totalSeconds)) }
  func end() { events.append(.end) }
}
