import CoreModels
import Foundation

public actor FeedbackCache {
  private let store: JSONFileCache<[CoachFeedback]>

  public init(directory: URL? = nil) {
    store = JSONFileCache(directory: directory)
  }

  public func save(feedback: [CoachFeedback], studentID: UUID) async throws {
    try await store.save(feedback, fileName: "student-\(studentID.uuidString)-feedback.json")
  }

  public func loadFeedback(studentID: UUID) async -> [CoachFeedback]? {
    await store.load(fileName: "student-\(studentID.uuidString)-feedback.json")
  }
}
