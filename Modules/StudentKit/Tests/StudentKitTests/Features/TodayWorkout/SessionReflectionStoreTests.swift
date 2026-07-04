import Foundation
import Testing

@testable import StudentKit

/// Reflections must survive dismiss (the bug: collected then discarded) and stay
/// scoped per student + per day.
@Suite struct SessionReflectionStoreTests {
  private func makeStore() -> (UserDefaultsSessionReflectionStore, UserDefaults) {
    let suite = "test.reflection.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (UserDefaultsSessionReflectionStore(defaults: defaults), defaults)
  }

  @Test func savesAndReloadsReflection() {
    let (store, _) = makeStore()
    let student = UUID()
    let day = Date(timeIntervalSince1970: 1_720_051_200)  // 2024-07-04

    store.save(
      SessionReflection(mindset: "破 PR", achievements: "深蹲稳", improvements: "握力"),
      studentId: student, date: day)

    let loaded = store.reflection(studentId: student, date: day)
    #expect(loaded.mindset == "破 PR")
    #expect(loaded.achievements == "深蹲稳")
    #expect(loaded.improvements == "握力")
  }

  @Test func unknownDayReturnsEmpty() {
    let (store, _) = makeStore()
    let student = UUID()
    store.save(SessionReflection(mindset: "今天"), studentId: student, date: Date())

    let otherDay = Date(timeIntervalSince1970: 0)
    #expect(store.reflection(studentId: student, date: otherDay).isEmpty)
  }

  @Test func differentStudentsDoNotShareReflections() {
    let (store, _) = makeStore()
    let day = Date(timeIntervalSince1970: 1_720_051_200)
    let studentA = UUID()
    let studentB = UUID()

    store.save(SessionReflection(mindset: "A 的笔记"), studentId: studentA, date: day)
    #expect(store.reflection(studentId: studentB, date: day).isEmpty)
    #expect(store.reflection(studentId: studentA, date: day).mindset == "A 的笔记")
  }

  @Test func emptyReflectionClearsStoredRecord() {
    let (store, _) = makeStore()
    let student = UUID()
    let day = Date(timeIntervalSince1970: 1_720_051_200)

    store.save(SessionReflection(mindset: "临时"), studentId: student, date: day)
    store.save(SessionReflection(), studentId: student, date: day)

    #expect(store.reflection(studentId: student, date: day).isEmpty)
  }

  @Test func sameCalendarDayReloadsRegardlessOfTimeOfDay() {
    let (store, _) = makeStore()
    let student = UUID()
    // Constructed from components so both are the same *local* calendar day,
    // independent of the test machine's timezone.
    var comps = DateComponents()
    comps.year = 2024
    comps.month = 7
    comps.day = 4
    comps.hour = 8
    let morning = Calendar.current.date(from: comps)!
    comps.hour = 20
    let evening = Calendar.current.date(from: comps)!

    store.save(SessionReflection(mindset: "早上写的"), studentId: student, date: morning)
    #expect(store.reflection(studentId: student, date: evening).mindset == "早上写的")
  }
}
