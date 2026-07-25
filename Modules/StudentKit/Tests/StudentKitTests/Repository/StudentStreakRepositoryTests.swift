import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

@Test("demo streak repository returns the fixed sample value")
func demoStreakRepositoryReturnsTwelve() async throws {
  let repository = InMemoryStudentStreakRepository(current: 12)
  let streak = try await repository.currentStreak()

  #expect(streak?.current == 12)
}

@Test("live streak repository maps a missing endpoint to no data")
func liveStreakRepositoryMapsNotFoundToNil() async throws {
  let api = APIClient(
    environment: ["MEETPR_API_BASE_URL": "https://api.test"]
  ) { _ in
    APIResponse(data: Data("{}".utf8), statusCode: 404)
  }
  let repository = BackendStudentStreakRepository(
    api: api,
    session: StudentStreakSessionReader()
  )

  #expect(try await repository.currentStreak() == nil)
}

private struct StudentStreakSessionReader: SessionStateReader {
  func accessToken() async throws -> String {
    "student-token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}
