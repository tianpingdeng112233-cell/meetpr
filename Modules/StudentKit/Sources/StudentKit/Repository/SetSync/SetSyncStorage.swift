import Foundation

@MainActor protocol SetSyncStorage {
  func read(account: UUID, name: String) throws -> Data?
  func write(_ data: Data, account: UUID, name: String) throws
}

@MainActor final class FileSetSyncStorage: SetSyncStorage {
  private let directory: URL

  init(directory: URL = URL.documentsDirectory.appending(path: "set_sync")) {
    self.directory = directory
  }

  func read(account: UUID, name: String) throws -> Data? {
    let url = file(account: account, name: name)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try Data(contentsOf: url)
  }

  func write(_ data: Data, account: UUID, name: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: file(account: account, name: name), options: .atomic)
  }

  private func file(account: UUID, name: String) -> URL {
    directory.appending(path: "\(account.uuidString)-\(name).json")
  }
}

@MainActor final class MemorySetSyncStorage: SetSyncStorage {
  private var values: [String: Data] = [:]

  func read(account: UUID, name: String) -> Data? { values["\(account)-\(name)"] }
  func write(_ data: Data, account: UUID, name: String) {
    values["\(account)-\(name)"] = data
  }
}
