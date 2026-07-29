import CoreModels
import Foundation

public actor ExerciseCatalogCache {
  public struct Snapshot: Codable, Equatable, Sendable {
    public let exercises: [Exercise]
    public let etag: String?

    public init(exercises: [Exercise], etag: String?) {
      self.exercises = exercises
      self.etag = etag
    }
  }

  private static let fileVersion = 1
  private let store: JSONFileCache<Snapshot>

  public init(directory: URL? = nil) {
    store = JSONFileCache(directory: directory)
  }

  public func save(exercises: [Exercise], etag: String?) async throws {
    try await store.save(
      Snapshot(exercises: exercises, etag: etag),
      fileName: fileName
    )
  }

  public func load() async -> Snapshot? {
    await store.load(fileName: fileName)
  }

  private var fileName: String {
    "exercise-catalog-v\(Self.fileVersion).json"
  }
}
