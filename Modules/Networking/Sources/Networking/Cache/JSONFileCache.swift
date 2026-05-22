import CoreModels
import Foundation

actor JSONFileCache<Value: Codable & Sendable> {
  private let directory: URL
  private let fileManager: FileManager

  init(directory: URL? = nil, fileManager: FileManager = .default) {
    self.fileManager = fileManager
    self.directory =
      directory
      ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appending(path: "MeetPRNetworkingCache", directoryHint: .isDirectory)
  }

  func save(_ value: Value, fileName: String) throws {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try MeetPRCodec.encoder.encode(value)
    try data.write(to: fileURL(fileName: fileName), options: [.atomic])
  }

  func load(fileName: String) -> Value? {
    let url = fileURL(fileName: fileName)

    do {
      let data = try Data(contentsOf: url)
      return try MeetPRCodec.decoder.decode(Value.self, from: data)
    } catch {
      try? fileManager.removeItem(at: url)
      return nil
    }
  }

  func remove(fileName: String) {
    try? fileManager.removeItem(at: fileURL(fileName: fileName))
  }

  private func fileURL(fileName: String) -> URL {
    directory.appending(path: fileName)
  }
}
