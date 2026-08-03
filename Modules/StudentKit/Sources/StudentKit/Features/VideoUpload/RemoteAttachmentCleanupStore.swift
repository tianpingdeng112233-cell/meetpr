import Foundation

public protocol RemoteAttachmentCleanupStoring: Sendable {
  func enqueue(_ attachmentID: UUID) async throws
  func remove(_ attachmentID: UUID) async throws
  func pendingAttachmentIDs() async throws -> Set<UUID>
}

actor RemoteAttachmentCleanupStore: RemoteAttachmentCleanupStoring {
  private let fileURL: URL
  private var cached: Set<UUID>?

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func enqueue(_ attachmentID: UUID) throws {
    var pending = try load()
    pending.insert(attachmentID)
    try persist(pending)
  }

  func remove(_ attachmentID: UUID) throws {
    var pending = try load()
    pending.remove(attachmentID)
    try persist(pending)
  }

  func pendingAttachmentIDs() throws -> Set<UUID> {
    try load()
  }

  private func load() throws -> Set<UUID> {
    if let cached { return cached }
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      cached = []
      return []
    }
    let identifiers = try JSONDecoder().decode([UUID].self, from: Data(contentsOf: fileURL))
    let loaded = Set(identifiers)
    cached = loaded
    return loaded
  }

  private func persist(_ identifiers: Set<UUID>) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try JSONEncoder().encode(identifiers.sorted { $0.uuidString < $1.uuidString })
      .write(to: fileURL, options: .atomic)
    cached = identifiers
  }
}
