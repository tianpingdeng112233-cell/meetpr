import CoreModels
import Foundation
import RepositoryContracts

/// Dictionary-backed store for tests, previews, and demo builds. Playback is
/// unsupported (no backend) — `playbackURL` is always nil.
public actor InMemoryVideoAttachmentRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment] = [:]

  public init(seed: [VideoAttachment] = []) {
    for attachment in seed {
      storage[attachment.id] = attachment
    }
  }

  public func save(_ attachment: VideoAttachment) async throws {
    storage[attachment.id] = attachment
  }

  public func fetch(id: UUID) async throws -> VideoAttachment? {
    storage[id]
  }

  public func fetch(setLogID: UUID) async throws -> [VideoAttachment] {
    storage.values
      .filter { $0.setLogID == setLogID }
      .sorted { $0.recordedAt < $1.recordedAt }
  }

  public func fetchAll(studentID: UUID) async throws -> [VideoAttachment] {
    storage.values
      .filter { $0.studentID == studentID }
      .sorted { $0.recordedAt < $1.recordedAt }
  }

  public func delete(id: UUID) async throws {
    storage[id] = nil
  }

  public func playbackURL(for attachment: VideoAttachment) async throws -> URL? {
    nil
  }
}
