import Foundation

/// JSON-file draft persistence under Application Support/MeetPR/onboarding/ (spec 032 D6;
/// LocalE1RMRepository precedent — ADR-009's SwiftData exception does not
/// extend here). The draft is a resilience copy, not a source of truth, so
/// a corrupted file reads as nil instead of throwing (spec 032 test plan).
public actor LocalOnboardingDraftStore {
  private let directory: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(directory: URL? = nil) {
    self.directory = directory ?? SecureLocalStorage.directory(relativePath: "onboarding")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    self.encoder = encoder
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  public func load(studentId: UUID) -> OnboardingDraft? {
    guard let data = try? Data(contentsOf: fileURL(studentId)) else { return nil }
    return try? decoder.decode(OnboardingDraft.self, from: data)
  }

  public func save(_ draft: OnboardingDraft, studentId: UUID) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try encoder.encode(draft).write(to: fileURL(studentId), options: .atomic)
    SecureLocalStorage.harden(directory)
    SecureLocalStorage.harden(fileURL(studentId))
  }

  public func clear(studentId: UUID) {
    try? FileManager.default.removeItem(at: fileURL(studentId))
  }

  private func fileURL(_ studentId: UUID) -> URL {
    directory.appendingPathComponent("draft-\(studentId.uuidString).json")
  }
}
