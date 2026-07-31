import Foundation
import Testing

@testable import RepositoryContracts

@Test("in-memory video markers create, sort, isolate by video, and delete")
func inMemoryVideoMarkerLifecycle() async throws {
  let coachID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000621"))
  let videoID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000622"))
  let otherVideoID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000623"))
  let ids = IDSequence([
    try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000631")),
    try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000632")),
    try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000633")),
  ])
  let repository = InMemoryVideoMarkerRepository(
    coachID: coachID,
    now: { Date(timeIntervalSince1970: 100) },
    makeID: { ids.next() }
  )

  let later = try await repository.createMarker(
    videoID: videoID,
    timeMilliseconds: 4_000,
    level: .warn,
    note: "Brace"
  )
  let earlier = try await repository.createMarker(
    videoID: videoID,
    timeMilliseconds: 500,
    level: .bad,
    note: "Depth"
  )
  _ = try await repository.createMarker(
    videoID: otherVideoID,
    timeMilliseconds: 100,
    level: .info,
    note: "Other"
  )

  let markers = try await repository.markers(videoID: videoID)
  #expect(markers.map(\.id) == [earlier.id, later.id])
  #expect(markers.allSatisfy { $0.coachID == coachID && $0.videoID == videoID })

  try await repository.deleteMarker(videoID: videoID, markerID: earlier.id)
  #expect(try await repository.markers(videoID: videoID).map(\.id) == [later.id])
  await #expect(throws: VideoMarkerRepositoryError.notFound) {
    try await repository.deleteMarker(videoID: otherVideoID, markerID: later.id)
  }
}

private final class IDSequence: @unchecked Sendable {
  private let lock = NSLock()
  private var ids: [UUID]

  init(_ ids: [UUID]) {
    self.ids = ids
  }

  func next() -> UUID {
    lock.lock()
    defer { lock.unlock() }
    return ids.removeFirst()
  }
}
