import CoreModels
import Foundation
import Networking
import NetworkingTestSupport
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func ownerSwitchMidFlightPreventsFetchAndStartCacheWrites() async throws {
  let userA = makeUser(
    id: try #require(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
  )
  let userB = makeUser(
    id: try #require(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
  )
  let session = SwitchableSessionReader(user: userA)
  let harness = StubHTTPHarness()
  let repository = BackendTrainingSessionRepository(
    api: makeAPIClient(harness: harness),
    session: session,
    calendar: utcCalendar()
  )
  let sessionDate = try Date("2026-07-17T10:00:00Z", strategy: .iso8601)
  let observationDate = try Date("2026-07-18T00:00:00Z", strategy: .iso8601)

  harness.onRequest = { _ in session.replaceUser(with: userB) }
  harness.enqueue(body: completedSessionResponse)

  let fetched = try await repository.fetchSession(on: sessionDate)
  #expect(fetched.session?.status == .completed)
  #expect(await repository.recentCompletedSession(before: observationDate) == nil)

  session.replaceUser(with: userA)
  #expect(await repository.recentCompletedSession(before: observationDate) == nil)

  harness.onRequest = { _ in session.replaceUser(with: userB) }
  harness.enqueue(body: completedStartResponse)

  let started = try await repository.startSession()
  #expect(started.session?.status == .completed)
  #expect(await repository.recentCompletedSession(before: observationDate) == nil)

  session.replaceUser(with: userA)
  #expect(await repository.recentCompletedSession(before: observationDate) == nil)
}

@Test func nullSessionCacheDeletionRequiresStableOwner() async throws {
  let userA = makeUser(
    id: try #require(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
  )
  let userB = makeUser(
    id: try #require(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
  )
  let session = SwitchableSessionReader(user: userA)
  let harness = StubHTTPHarness()
  let repository = BackendTrainingSessionRepository(
    api: makeAPIClient(harness: harness),
    session: session,
    calendar: utcCalendar()
  )
  let sessionDate = try Date("2026-07-17T10:00:00Z", strategy: .iso8601)
  let observationDate = try Date("2026-07-18T00:00:00Z", strategy: .iso8601)

  harness.enqueue(body: completedSessionResponse)
  _ = try await repository.fetchSession(on: sessionDate)
  #expect(await repository.recentCompletedSession(before: observationDate)?.status == .completed)

  harness.onRequest = { _ in session.replaceUser(with: userB) }
  harness.enqueue(body: nullSessionResponse)
  _ = try await repository.fetchSession(on: sessionDate)

  session.replaceUser(with: userA)
  #expect(await repository.recentCompletedSession(before: observationDate)?.status == .completed)

  harness.onRequest = nil
  harness.enqueue(body: nullSessionResponse)
  _ = try await repository.fetchSession(on: sessionDate)
  #expect(await repository.recentCompletedSession(before: observationDate) == nil)
}

private let completedSessionResponse = Data(
  """
  {
    "gym_day": "2026-07-17",
    "session": {
      "status": "completed",
      "started_at": "2026-07-17T10:00:00Z",
      "last_set_at": "2026-07-17T11:00:00Z",
      "completed_at": "2026-07-17T11:00:00Z",
      "duration_seconds": 3600
    }
  }
  """.utf8
)

// A COMPLETED session on a day the fetch part never touches: startSession may
// legitimately return one (idempotent POST), and only completed entries are
// visible through recentCompletedSession — an in-progress fixture could never
// catch an owner-gate regression on the start path.
private let completedStartResponse = Data(
  """
  {
    "gym_day": "2026-07-16",
    "session": {
      "status": "completed",
      "started_at": "2026-07-16T10:00:00Z",
      "last_set_at": "2026-07-16T11:00:00Z",
      "completed_at": "2026-07-16T11:00:00Z",
      "duration_seconds": 3600
    }
  }
  """.utf8
)

private let nullSessionResponse = Data(
  """
  {
    "gym_day": "2026-07-17",
    "session": null
  }
  """.utf8
)

private func makeAPIClient(harness: StubHTTPHarness) -> APIClient {
  APIClient(
    environment: ["MEETPR_API_BASE_URL": "https://api.test"],
    transport: harness.transport
  )
}

private func makeUser(id: UUID) -> User {
  User(
    id: id,
    phone: "+8613800000001",
    unitSystem: .metric,
    role: .coachedStudent,
    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
    updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
  )
}

private func utcCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar
}

private final class SwitchableSessionReader: SessionStateReader, @unchecked Sendable {
  private let lock = NSLock()
  private var storedUser: User

  init(user: User) {
    storedUser = user
  }

  func accessToken() async throws -> String {
    "token"
  }

  func currentUser() async throws -> User {
    readUser()
  }

  func replaceUser(with user: User) {
    lock.lock()
    storedUser = user
    lock.unlock()
  }

  private func readUser() -> User {
    lock.lock()
    defer { lock.unlock() }
    return storedUser
  }
}
