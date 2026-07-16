import CoreModels
import Foundation
import Testing

@testable import StudentKit

private func makeReviewStores() -> [(String, any ImportedHistoryReviewStoring)] {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "imported-review-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
  return [
    ("InMemory", InMemoryImportedHistoryReviewStore()),
    ("Local", LocalImportedHistoryReviewStore(directory: directory)),
  ]
}

private func reviewRecord(
  studentID: UUID,
  family: LiftFamily = .squat
) -> ImportedHistoryReviewRecord {
  ImportedHistoryReviewRecord(
    studentID: studentID,
    family: family,
    decision: .confirmed,
    reviewedMaxE1RM: 180
  )
}

private func pendingReview(
  studentID: UUID,
  family: LiftFamily = .squat
) -> PendingImportedHistoryReview {
  PendingImportedHistoryReview(
    id: UUID(),
    studentID: studentID,
    family: family,
    pointIDs: [UUID(), UUID()],
    reviewedMaxE1RM: 180,
    baseline1RMKg: 160,
    sourceWeightKg: 150,
    sourceReps: 4,
    sourceE1RMKg: 180
  )
}

@Test func reviewRecordAndPendingReviewRoundTrip() async throws {
  for (label, store) in makeReviewStores() {
    let student = UUID()
    let record = reviewRecord(studentID: student)
    let pending = pendingReview(studentID: student)

    try await store.save(review: record)
    try await store.save(pendingReview: pending)

    #expect(try await store.review(studentID: student, family: .squat) == record, "\(label)")
    #expect(
      try await store.pendingReview(studentID: student, family: .squat) == pending,
      "\(label)"
    )
    #expect(record.decision.confidence == .normal, "\(label)")
    #expect(ImportedHistoryReviewDecision.rejected.confidence == .low, "\(label)")
  }
}

@Test func reviewStoresIsolateRecordsByStudentAndFamily() async throws {
  for (label, store) in makeReviewStores() {
    let firstStudent = UUID()
    let secondStudent = UUID()
    let firstStudentSquat = reviewRecord(studentID: firstStudent)
    let firstStudentBench = reviewRecord(studentID: firstStudent, family: .bench)
    let secondStudentSquat = reviewRecord(studentID: secondStudent)
    let firstPending = pendingReview(studentID: firstStudent)
    let secondPending = pendingReview(studentID: secondStudent)

    try await store.save(review: firstStudentSquat)
    try await store.save(review: firstStudentBench)
    try await store.save(review: secondStudentSquat)
    try await store.save(pendingReview: firstPending)
    try await store.save(pendingReview: secondPending)

    #expect(
      try await store.review(studentID: firstStudent, family: .squat) == firstStudentSquat,
      "\(label)"
    )
    #expect(
      try await store.review(studentID: firstStudent, family: .bench) == firstStudentBench,
      "\(label)"
    )
    #expect(
      try await store.review(studentID: secondStudent, family: .squat) == secondStudentSquat,
      "\(label)"
    )
    #expect(
      try await store.pendingReview(studentID: firstStudent, family: .squat) == firstPending,
      "\(label)"
    )
    #expect(
      try await store.pendingReview(studentID: secondStudent, family: .squat) == secondPending,
      "\(label)"
    )
    #expect(try await store.review(studentID: secondStudent, family: .bench) == nil, "\(label)")
  }
}

@Test func removePendingReviewRemovesOnlyMatchingStudentAndFamily() async throws {
  for (label, store) in makeReviewStores() {
    let student = UUID()
    let squat = pendingReview(studentID: student)
    let bench = pendingReview(studentID: student, family: .bench)
    let record = reviewRecord(studentID: student)
    try await store.save(review: record)
    try await store.save(pendingReview: squat)
    try await store.save(pendingReview: bench)

    try await store.removePendingReview(studentID: student, family: .squat)

    #expect(try await store.pendingReview(studentID: student, family: .squat) == nil, "\(label)")
    #expect(try await store.pendingReview(studentID: student, family: .bench) == bench, "\(label)")
    #expect(try await store.review(studentID: student, family: .squat) == record, "\(label)")
  }
}

@Test func localReviewStorePersistsAcrossInstances() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "imported-review-persist-\(UUID().uuidString)", directoryHint: .isDirectory)
  let student = UUID()
  let record = reviewRecord(studentID: student)
  let pending = pendingReview(studentID: student)

  let first = LocalImportedHistoryReviewStore(directory: directory)
  try await first.save(review: record)
  try await first.save(pendingReview: pending)

  let second = LocalImportedHistoryReviewStore(directory: directory)
  #expect(try await second.review(studentID: student, family: .squat) == record)
  #expect(try await second.pendingReview(studentID: student, family: .squat) == pending)
}
