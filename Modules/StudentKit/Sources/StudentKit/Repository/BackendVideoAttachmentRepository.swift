import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// File-backed attachment store + backend playback URLs (spec 027).
///
/// Records (including the setLog ↔ attachment association) persist to a JSON
/// file under Application Support/MeetPR/video_attachments/ — the LocalE1RMRepository
/// precedent — because backend spec 004 keeps attachments association-free.
/// Only `playbackURL` talks to the backend (`GET /uploads/:id/url`).
public actor BackendVideoAttachmentRepository: VideoAttachmentRepository {
  private let api: APIClient
  private let session: any SessionStateReader
  private let directory: URL
  private var cached: [VideoAttachment]?

  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(api: APIClient, session: any SessionStateReader, directory: URL? = nil) {
    self.api = api
    self.session = session
    self.directory = directory ?? SecureLocalStorage.directory(relativePath: "video_attachments")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    self.encoder = encoder
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  // MARK: - VideoAttachmentRepository

  public func save(_ attachment: VideoAttachment) async throws {
    var all = try load()
    if let index = all.firstIndex(where: { $0.id == attachment.id }) {
      all[index] = attachment
    } else {
      all.append(attachment)
    }
    try persist(all)
  }

  public func fetch(id: UUID) async throws -> VideoAttachment? {
    try load().first { $0.id == id }
  }

  public func fetch(setLogID: UUID) async throws -> [VideoAttachment] {
    try load()
      .filter { $0.setLogID == setLogID }
      .sorted { $0.recordedAt < $1.recordedAt }
  }

  public func fetchAll(studentID: UUID) async throws -> [VideoAttachment] {
    try load()
      .filter { $0.studentID == studentID }
      .sorted { $0.recordedAt < $1.recordedAt }
  }

  public func delete(id: UUID) async throws {
    var all = try load()
    all.removeAll { $0.id == id }
    try persist(all)
  }

  public func playbackURL(for attachment: VideoAttachment) async throws -> URL? {
    guard attachment.status == .uploaded, let remoteID = attachment.remoteAttachmentID else {
      return nil
    }
    let token = try await session.accessToken()
    let response = try await api.attachmentURL(attachmentID: remoteID, accessToken: token)
    return URL(string: response.url)
  }

  // MARK: - File IO

  private var fileURL: URL { directory.appendingPathComponent("attachments.json") }

  // Missing file = genuinely empty store. Decode failures must throw so a
  // corrupt file never silently erases upload history on the next save.
  private func load() throws -> [VideoAttachment] {
    if let cached { return cached }
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      cached = []
      return []
    }
    let loaded = try decoder.decode([VideoAttachment].self, from: Data(contentsOf: fileURL))
    cached = loaded
    return loaded
  }

  private func persist(_ attachments: [VideoAttachment]) throws {
    cached = attachments
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try encoder.encode(attachments).write(to: fileURL, options: .atomic)
    SecureLocalStorage.harden(directory)
    SecureLocalStorage.harden(fileURL)
  }
}
