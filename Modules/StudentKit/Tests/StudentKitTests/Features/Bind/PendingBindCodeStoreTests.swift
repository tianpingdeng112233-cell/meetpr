import Foundation
import Testing

@testable import StudentKit

/// Unique suite per test — Swift Testing runs tests concurrently and a
/// shared suite would cross-contaminate.
private func makeStore() -> UserDefaultsPendingBindCodeStore {
  let suiteName = "PendingBindCodeStoreTests.\(UUID().uuidString)"
  UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
  return UserDefaultsPendingBindCodeStore(suiteName: suiteName)
}

@Test func stashPeekClearRoundTrip() {
  let store = makeStore()
  let studentId = BindFixtures.studentId
  let pending = BindFixtures.pendingCode()

  #expect(store.peek(studentId: studentId) == nil)

  store.stash(pending, studentId: studentId)
  #expect(store.peek(studentId: studentId) == pending)

  store.clear(studentId: studentId)
  #expect(store.peek(studentId: studentId) == nil)
}

@Test func stashOverwritesPreviousValue() {
  let store = makeStore()
  let studentId = BindFixtures.studentId
  store.stash(BindFixtures.pendingCode(code: "XK7MPQ2RVT"), studentId: studentId)
  store.stash(BindFixtures.pendingCode(code: "ABCDEFGHJK"), studentId: studentId)

  #expect(store.peek(studentId: studentId)?.code == "ABCDEFGHJK")
}

@Test func studentsAreIsolatedByKey() {
  let store = makeStore()
  let studentA = BindFixtures.studentId
  let studentB = UUID(uuidString: "0b000000-0000-0000-0000-000000000002")!

  store.stash(BindFixtures.pendingCode(code: "XK7MPQ2RVT"), studentId: studentA)

  #expect(store.peek(studentId: studentB) == nil)

  store.stash(BindFixtures.pendingCode(code: "ABCDEFGHJK"), studentId: studentB)
  store.clear(studentId: studentA)

  #expect(store.peek(studentId: studentA) == nil)
  #expect(store.peek(studentId: studentB)?.code == "ABCDEFGHJK")
}
