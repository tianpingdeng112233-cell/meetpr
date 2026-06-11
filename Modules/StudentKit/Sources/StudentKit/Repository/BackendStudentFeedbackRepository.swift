import CoreModels
import Foundation
import Networking
import RepositoryContracts

public actor BackendStudentFeedbackRepository: StudentFeedbackRepository {
  private let api: APIClient
  private let session: any SessionStateReader
  private let cache: FeedbackCache

  public init(
    api: APIClient,
    session: any SessionStateReader,
    cache: FeedbackCache = FeedbackCache()
  ) {
    self.api = api
    self.session = session
    self.cache = cache
  }

  public func fetchInbox(studentID: UUID) async throws -> [CoachFeedback] {
    let token = try await session.accessToken()
    do {
      let response = try await api.studentFeedback(studentID: studentID, accessToken: token)
      let feedback = response.items.map { $0.toDomain() }.sorted { $0.postedAt > $1.postedAt }
      try await cache.save(feedback: feedback, studentID: studentID)
      return feedback
    } catch {
      if let cached = await cache.loadFeedback(studentID: studentID) {
        return cached
      }
      throw error
    }
  }

  public func postFeedback(
    studentID: UUID,
    dayDate: Date?,
    planExerciseID: UUID?,
    text: String
  ) async throws -> CoachFeedback {
    let token = try await session.accessToken()
    let response = try await api.createFeedback(
      CreateFeedbackRequestDTO(
        studentID: studentID,
        dayDate: dayDate,
        planExerciseID: planExerciseID,
        text: text
      ),
      accessToken: token
    )
    let item = response.toDomain()
    var cached = await cache.loadFeedback(studentID: studentID) ?? []
    cached.removeAll { $0.id == item.id }
    cached.append(item)
    try await cache.save(
      feedback: cached.sorted { $0.postedAt > $1.postedAt }, studentID: studentID)
    return item
  }

  public func markRead(feedbackID: UUID) async throws {
    let token = try await session.accessToken()
    try await api.markFeedbackRead(id: feedbackID, accessToken: token)
  }
}
