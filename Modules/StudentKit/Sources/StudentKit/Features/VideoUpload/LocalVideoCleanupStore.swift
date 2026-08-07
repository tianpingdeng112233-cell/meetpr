import Foundation

public protocol LocalVideoCleanupStoring: Sendable {
  func enqueue(_ fileName: String) async throws
  func remove(_ fileName: String) async throws
  func pendingFileNames() async throws -> Set<String>
}

actor LocalVideoCleanupStore: LocalVideoCleanupStoring {
  private let fileURL: URL
  private var cached: Set<String>?

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func enqueue(_ fileName: String) throws {
    var pending = try load()
    pending.insert(fileName)
    try persist(pending)
  }

  func remove(_ fileName: String) throws {
    var pending = try load()
    pending.remove(fileName)
    try persist(pending)
  }

  func pendingFileNames() throws -> Set<String> {
    try load()
  }

  private func load() throws -> Set<String> {
    if let cached { return cached }
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      cached = []
      return []
    }
    let fileNames = try JSONDecoder().decode([String].self, from: Data(contentsOf: fileURL))
    let loaded = Set(fileNames)
    cached = loaded
    return loaded
  }

  private func persist(_ fileNames: Set<String>) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try JSONEncoder().encode(fileNames.sorted())
      .write(to: fileURL, options: .atomic)
    cached = fileNames
  }
}
