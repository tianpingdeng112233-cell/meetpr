import Foundation
import Testing

@testable import StudentKit

@Test func restRingDurationUsesCoachThenExerciseCategory() {
  #expect(
    RestRingModel.duration(coachSeconds: 75, isAccessory: false, main: 180, accessory: 60) == 75)
  #expect(
    RestRingModel.duration(coachSeconds: nil, isAccessory: false, main: 210, accessory: 90) == 210)
  #expect(
    RestRingModel.duration(coachSeconds: nil, isAccessory: true, main: 210, accessory: 90) == 90)
  #expect(
    RestRingModel.duration(coachSeconds: 1200, isAccessory: true, main: 180, accessory: 60) == 900)
}

@Test func restRingRunsToDoneThenReturnsToIdleOnWallClock() {
  let now = Date(timeIntervalSince1970: 1000)
  var ring = RestRingModel()
  #expect(ring.phase == .idle)
  ring.start(seconds: 30, exercise: "Bench", at: now)
  #expect(ring.phase == .running)
  #expect(ring.remaining(at: now.addingTimeInterval(12)) == 18)
  ring.tick(at: now.addingTimeInterval(30))
  #expect(ring.phase == .done)
  ring.tick(at: now.addingTimeInterval(33))
  #expect(ring.phase == .idle)
}

@Test func restRingAdjustsWithinBoundsAndCanEndOrCompleteTodaySilently() {
  let now = Date(timeIntervalSince1970: 1000)
  var ring = RestRingModel()
  ring.start(seconds: 900, exercise: "Bench", at: now)
  ring.adjust(by: 15, at: now)
  #expect(ring.remaining(at: now) == 900)
  ring.adjust(by: -15, at: now)
  #expect(ring.remaining(at: now) == 885)
  ring.end()
  #expect(ring.phase == .idle)
  ring.start(seconds: 10, exercise: "Row", at: now)
  ring.adjust(by: -15, at: now)
  #expect(ring.remaining(at: now) == 0)
  #expect(ring.phase == .done)
  ring.end()
  ring.start(seconds: 60, exercise: "Row", at: now)
  ring.completeToday()
  #expect(ring.phase == .idle)
  #expect(ring.endsAt == nil)
}

@Test func restRingChoosesExpandedThenHighlightedThenLastExercise() {
  let first = UUID()
  let second = UUID()
  let third = UUID()
  #expect(
    RestRingModel.currentExercise(
      ids: [first, second, third], expanded: first, highlighted: second) == first)
  #expect(
    RestRingModel.currentExercise(ids: [first, second, third], expanded: nil, highlighted: second)
      == second)
  #expect(
    RestRingModel.currentExercise(ids: [first, second, third], expanded: nil, highlighted: nil)
      == third)
  #expect(RestRingModel.currentExercise(ids: [], expanded: first, highlighted: second) == nil)
}

@Test func restRingAlertsOnlyOncePerLastTenSecondsAndRespectsForegroundAndSwitches() {
  let start = Date(timeIntervalSince1970: 1000)
  var ring = RestRingModel()
  ring.start(seconds: 30, exercise: "Bench", at: start)
  var vibrationSeconds: [Int] = []
  var soundSeconds: [Int] = []
  for second in 0...33 {
    let alert = ring.tick(at: start.addingTimeInterval(Double(second)))
    if alert.vibrate { vibrationSeconds.append(second) }
    if alert.sound { soundSeconds.append(second) }
    #expect(ring.tick(at: start.addingTimeInterval(Double(second))) == .silent)
  }
  #expect(vibrationSeconds == [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30])
  #expect(soundSeconds == [30])
  ring.start(seconds: 10, exercise: "Bench", at: start)
  #expect(ring.tick(at: start, foreground: false) == .silent)
  #expect(ring.tick(at: start.addingTimeInterval(1), vibration: false) == .silent)
  let end = ring.tick(at: start.addingTimeInterval(10), vibration: false, sound: true)
  #expect(!end.vibrate && end.sound)
  ring.start(seconds: 10, exercise: "Bench", at: start)
  let silentSound = ring.tick(at: start.addingTimeInterval(10), sound: false)
  #expect(silentSound.vibrate && !silentSound.sound)
  ring.start(seconds: 10, exercise: "Bench", at: start)
  ring.completeToday()
  #expect(ring.tick(at: start.addingTimeInterval(10)) == .silent)
}

@Test func restRingMigratesThreeLegacyStorageShapes() {
  let bands = Data(#"{"version":2,"lowSeconds":120,"midSeconds":210,"highSeconds":240}"#.utf8)
  let custom = RestRingSettings.migrate(bands: bands, fixed: nil, accessory: 90)
  #expect(custom.mainSeconds == 210 && custom.accessorySeconds == 90)
  let fixed = RestRingSettings.migrate(bands: nil, fixed: 195, accessory: 750)
  #expect(fixed.mainSeconds == 195 && fixed.accessorySeconds == 600)
  let automatic = RestRingSettings.migrate(bands: nil, fixed: nil, accessory: nil)
  #expect(automatic.mainSeconds == 180 && automatic.accessorySeconds == 60)
  #expect(automatic.vibration && automatic.sound)
  #expect(!automatic.didSaveFirstSettings && !automatic.didUseRing)
}

@Test func restRingFirstVisitShowsSettingsThenHintUntilFirstUse() throws {
  var settings = RestRingSettings()
  #expect(settings.needsFirstSettings)
  #expect(!settings.showsHint)
  settings.finishSetup()
  #expect(!settings.needsFirstSettings && settings.showsHint)
  let reloaded = try JSONDecoder().decode(
    RestRingSettings.self, from: JSONEncoder().encode(settings))
  #expect(reloaded.showsHint)
  settings.useRing()
  #expect(!settings.showsHint && !settings.needsFirstSettings)
  let nextVisit = try JSONDecoder().decode(
    RestRingSettings.self, from: JSONEncoder().encode(settings))
  #expect(!nextVisit.showsHint && !nextVisit.needsFirstSettings)
  #expect(RestRingSettings().needsFirstSettings)
}
