import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func cachedAddedLedgerCannotAuthorizeDerivedDeletionRepair() async throws {
  let studentID = UUID()
  let directory = URL.temporaryDirectory.appending(path: "spec092-cache-\(UUID())")
  defer { try? FileManager.default.removeItem(at: directory) }
  let cache = TrainingLogCache(directory: directory)
  let range = Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 1_700_000_000)
  try await cache.save(
    logs: [], studentID: studentID,
    from: WireFormatting.dateOnlyString(from: range.lowerBound),
    endDate: WireFormatting.exclusiveEndDateOnlyString(closedUpperBound: range.upperBound))
  let repository = BackendStudentTrainingLogRepository(
    api: APIClient(transport: { _ in throw URLError(.notConnectedToInternet) }),
    session: AddedCacheSession(), cache: cache)
  let cached = try await repository.fetchAllLogs(studentID: studentID, in: range)
  #expect(!cached.isAuthoritative)
  #expect(!cached.isCompleteLedger)
}

private struct AddedCacheSession: SessionStateReader {
  func accessToken() async throws -> String { "test-token" }
  func currentUser() async throws -> User { throw SessionStateReaderError.missingCurrentUser }
}
