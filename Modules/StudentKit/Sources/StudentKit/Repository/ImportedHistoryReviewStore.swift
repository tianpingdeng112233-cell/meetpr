import CoreModels
import Foundation

/// A student's answer to the one-time imported-history plausibility prompt.
enum ImportedHistoryReviewDecision: String, Codable, Equatable, Sendable {
  case confirmed
  case rejected

  var confidence: E1RMConfidence {
    switch self {
    case .confirmed: .normal
    case .rejected: .low
    }
  }
}

/// The durable answer watermark for one main-lift family. A later imported
/// batch only prompts again when it exceeds `reviewedMaxE1RM`.
struct ImportedHistoryReviewRecord: Codable, Equatable, Sendable {
  let studentID: UUID
  let family: LiftFamily
  let decision: ImportedHistoryReviewDecision
  let reviewedMaxE1RM: Double
}

/// A question that is visible but not yet answered. Persisting its exact point
/// IDs prevents a relaunch from either duplicating the prompt or allowing a
/// later answer to rewrite a previously reviewed batch.
struct PendingImportedHistoryReview: Codable, Equatable, Sendable {
  let id: UUID
  let studentID: UUID
  let family: LiftFamily
  let pointIDs: [UUID]
  let reviewedMaxE1RM: Double
  let baseline1RMKg: Double
  let sourceWeightKg: Double
  let sourceReps: Int
  let sourceE1RMKg: Double
}

extension PendingImportedHistoryReview: Identifiable {}

protocol ImportedHistoryReviewStoring: Sendable {
  func review(studentID: UUID, family: LiftFamily) async throws -> ImportedHistoryReviewRecord?
  func pendingReview(studentID: UUID, family: LiftFamily) async throws
    -> PendingImportedHistoryReview?
  func save(review: ImportedHistoryReviewRecord) async throws
  func save(pendingReview: PendingImportedHistoryReview) async throws
  func removePendingReview(studentID: UUID, family: LiftFamily) async throws
}

/// JSON-backed local persistence for imported-history answers. Its key carries
/// `studentID`, so different accounts on one device cannot share a decision.
actor LocalImportedHistoryReviewStore: ImportedHistoryReviewStoring {
  private struct Storage: Codable, Sendable {
    var reviews: [ImportedHistoryReviewRecord] = []
    var pendingReviews: [PendingImportedHistoryReview] = []
  }

  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private var cached: Storage?

  init(directory: URL? = nil) {
    let base =
      directory
      ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appending(path: "e1rm", directoryHint: .isDirectory)
    fileURL = base.appending(path: "imported-history-reviews.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    self.encoder = encoder
    decoder = JSONDecoder()
  }

  func review(studentID: UUID, family: LiftFamily) async throws -> ImportedHistoryReviewRecord? {
    try load().reviews.first { $0.studentID == studentID && $0.family == family }
  }

  func pendingReview(studentID: UUID, family: LiftFamily) async throws
    -> PendingImportedHistoryReview?
  {
    try load().pendingReviews.first { $0.studentID == studentID && $0.family == family }
  }

  func save(review: ImportedHistoryReviewRecord) async throws {
    var storage = try load()
    storage.reviews.removeAll { $0.studentID == review.studentID && $0.family == review.family }
    storage.reviews.append(review)
    try save(storage)
  }

  func save(pendingReview: PendingImportedHistoryReview) async throws {
    var storage = try load()
    storage.pendingReviews.removeAll {
      $0.studentID == pendingReview.studentID && $0.family == pendingReview.family
    }
    storage.pendingReviews.append(pendingReview)
    try save(storage)
  }

  func removePendingReview(studentID: UUID, family: LiftFamily) async throws {
    var storage = try load()
    let oldCount = storage.pendingReviews.count
    storage.pendingReviews.removeAll { $0.studentID == studentID && $0.family == family }
    if storage.pendingReviews.count != oldCount {
      try save(storage)
    }
  }

  private func load() throws -> Storage {
    if let cached { return cached }
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      let empty = Storage()
      cached = empty
      return empty
    }
    let storage = try decoder.decode(Storage.self, from: Data(contentsOf: fileURL))
    cached = storage
    return storage
  }

  private func save(_ storage: Storage) throws {
    cached = storage
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoder.encode(storage).write(to: fileURL, options: .atomic)
  }
}

actor InMemoryImportedHistoryReviewStore: ImportedHistoryReviewStoring {
  private var reviews: [ImportedHistoryReviewRecord]
  private var pendingReviews: [PendingImportedHistoryReview]

  init(
    reviews: [ImportedHistoryReviewRecord] = [],
    pendingReviews: [PendingImportedHistoryReview] = []
  ) {
    self.reviews = reviews
    self.pendingReviews = pendingReviews
  }

  func review(studentID: UUID, family: LiftFamily) async throws -> ImportedHistoryReviewRecord? {
    reviews.first { $0.studentID == studentID && $0.family == family }
  }

  func pendingReview(studentID: UUID, family: LiftFamily) async throws
    -> PendingImportedHistoryReview?
  {
    pendingReviews.first { $0.studentID == studentID && $0.family == family }
  }

  func save(review: ImportedHistoryReviewRecord) async throws {
    reviews.removeAll { $0.studentID == review.studentID && $0.family == review.family }
    reviews.append(review)
  }

  func save(pendingReview: PendingImportedHistoryReview) async throws {
    pendingReviews.removeAll {
      $0.studentID == pendingReview.studentID && $0.family == pendingReview.family
    }
    pendingReviews.append(pendingReview)
  }

  func removePendingReview(studentID: UUID, family: LiftFamily) async throws {
    pendingReviews.removeAll { $0.studentID == studentID && $0.family == family }
  }
}
