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
    endDate: String
  ) async throws {
    try await store.save(
      logs,
      fileName: fileName(studentID: studentID, from: from, endDate: endDate)
    )
  }

  public func loadLogs(studentID: UUID, from: String, endDate: String) async -> [StudentSetLog]? {
    await store.load(fileName: fileName(studentID: studentID, from: from, endDate: endDate))
  }

  private func fileName(studentID: UUID, from: String, endDate: String) -> String {
    "student-\(studentID.uuidString)-sets-\(from)-\(endDate).json"
  }
}
