import CoreModels
import Foundation

public actor TrainingLogCache {
  private let store: JSONFileCache<[StudentSetLog]>

  public init(directory: URL? = nil) {
    store = JSONFileCache(directory: directory)
  }

  public func save(
    logs: [StudentSetLog],
    studentID: UUID,
    from: String,
    endDate: String,
    scope: String = "plan"
  ) async throws {
    try await store.save(
      logs,
      fileName: fileName(studentID: studentID, from: from, endDate: endDate, scope: scope)
    )
  }

  public func loadLogs(
    studentID: UUID,
    from: String,
    endDate: String,
    scope: String = "plan"
  ) async -> [StudentSetLog]? {
    await store.load(
      fileName: fileName(studentID: studentID, from: from, endDate: endDate, scope: scope))
  }

  private func fileName(studentID: UUID, from: String, endDate: String, scope: String) -> String {
    // "plan" keeps the pre-spec-045 file names so existing caches survive.
    let suffix = scope == "plan" ? "" : "-\(scope)"
    return "student-\(studentID.uuidString)-sets-\(from)-\(endDate)\(suffix).json"
  }
}
