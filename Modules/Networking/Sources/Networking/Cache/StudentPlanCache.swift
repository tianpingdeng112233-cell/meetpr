import CoreModels
import Foundation

public actor StudentPlanCache {
  // v2 invalidates projections whose PrescribedSet.setIndex was cached as
  // one-based before the execution domain standardized on zero-based indexes.
  // v3 (spec 071): pre-sequence projections have no completion or canonical
  // day-order fields and must never be used to derive the cursor.
  private static let fileVersion = 3
  private let store: JSONFileCache<StudentPlanView>

  public init(directory: URL? = nil) {
    store = JSONFileCache(directory: directory)
  }

  public func save(plan: StudentPlanView, studentID: UUID) async throws {
    if let previous = await loadPlan(studentID: studentID), previous.cycleID != plan.cycleID {
      try await saveSnapshot(plan: previous, studentID: studentID)
    }
    try await saveSnapshot(plan: plan, studentID: studentID)
    try await store.save(plan, fileName: fileName(studentID: studentID))
  }

  public func saveSnapshot(plan: StudentPlanView, studentID: UUID) async throws {
    try await store.save(
      plan, fileName: snapshotFileName(planID: plan.cycleID, studentID: studentID))
  }

  public func loadPlan(id: UUID, studentID: UUID) async -> StudentPlanView? {
    if let current = await loadPlan(studentID: studentID), current.cycleID == id { return current }
    return await store.load(fileName: snapshotFileName(planID: id, studentID: studentID))
  }

  public func loadPlan(containing dayID: UUID, studentID: UUID) async -> StudentPlanView? {
    guard let current = await loadPlan(studentID: studentID) else { return nil }
    if current.days.contains(where: { $0.id == dayID }) { return current }
    for entry in current.handoff?.plans ?? [] where entry.id != current.cycleID {
      if let snapshot = await loadPlan(id: entry.id, studentID: studentID),
        snapshot.days.contains(where: { $0.id == dayID })
      {
        return snapshot
      }
    }
    return nil
  }

  private func snapshotFileName(planID: UUID, studentID: UUID) -> String {
    "student-\(studentID)-cycle-\(planID)-v\(Self.fileVersion).json"
  }

  public func loadPlan(studentID: UUID) async -> StudentPlanView? {
    await store.load(fileName: fileName(studentID: studentID))
  }

  public func removePlan(studentID: UUID) async {
    await store.remove(fileName: fileName(studentID: studentID))
  }

  private func fileName(studentID: UUID) -> String {
    "student-\(studentID.uuidString)-plan-v\(Self.fileVersion).json"
  }
}
