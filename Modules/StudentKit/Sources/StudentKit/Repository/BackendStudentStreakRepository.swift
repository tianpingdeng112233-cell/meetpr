import Networking
import RepositoryContracts

public actor BackendStudentStreakRepository: StudentStreakRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func currentStreak() async throws -> StudentTrainingStreak? {
    let token = try await session.accessToken()
    do {
      return try await api.studentStreak(accessToken: token).streak?.toDomain()
    } catch APIError.httpStatus(404, _) {
      return nil
    }
  }
}
