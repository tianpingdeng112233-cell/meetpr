import Foundation
import Testing

@testable import StudentKit

/// The review-completed flag must survive sheet dismissal and app restarts
/// (the bug: the completion control re-armed after 训练回顾 → 完成) and stay scoped
/// per student + per day.
@Suite struct SessionReviewStoreTests {
  private func makeStore() throws -> UserDefaultsSessionReviewStore {
    let suite = "test.review.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    return UserDefaultsSessionReviewStore(defaults: defaults)
  }

  @Test func marksAndReloadsCompletion() throws {
    let store = try makeStore()
    let student = UUID()
    let day = Date(timeIntervalSince1970: 1_720_051_200)  // 2024-07-04

    #expect(!store.didCompleteReview(studentId: student, date: day))
    store.markReviewCompleted(studentId: student, date: day)
    #expect(store.didCompleteReview(studentId: student, date: day))
  }

  @Test func otherDayStaysIncomplete() throws {
    let store = try makeStore()
    let student = UUID()
    store.markReviewCompleted(studentId: student, date: Date(timeIntervalSince1970: 1_720_051_200))

    #expect(!store.didCompleteReview(studentId: student, date: Date(timeIntervalSince1970: 0)))
  }

  @Test func differentStudentsDoNotShareCompletion() throws {
    let store = try makeStore()
    let day = Date(timeIntervalSince1970: 1_720_051_200)
    let studentA = UUID()
    let studentB = UUID()

    store.markReviewCompleted(studentId: studentA, date: day)
    #expect(!store.didCompleteReview(studentId: studentB, date: day))
    #expect(store.didCompleteReview(studentId: studentA, date: day))
  }

  @Test func sameCalendarDayMatchesRegardlessOfTimeOfDay() throws {
    let store = try makeStore()
    let student = UUID()
    // Constructed from components so both are the same *local* calendar day,
    // independent of the test machine's timezone.
    var comps = DateComponents()
    comps.year = 2024
    comps.month = 7
    comps.day = 4
    comps.hour = 8
    let morning = try #require(Calendar.current.date(from: comps))
    comps.hour = 20
    let evening = try #require(Calendar.current.date(from: comps))

    store.markReviewCompleted(studentId: student, date: morning)
    #expect(store.didCompleteReview(studentId: student, date: evening))
  }
}
