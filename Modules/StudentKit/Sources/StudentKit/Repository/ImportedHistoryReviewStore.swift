import CoreModels
import Foundation

public enum ImportedHistoryReviewDecision: String, Codable, Hashable, Sendable {
  case confirmed
  case rejected

  public var confidence: E1RMConfidence {
    switch self {
    case .confirmed: .normal
    case .rejected: .low
    }
  }
}

public struct ImportedHistoryReviewRecord: Codable, Hashable, Sendable {
  public let studentID: UUID
  public let family: LiftFamily
  public let decision: ImportedHistoryReviewDecision
  public let reviewedMaxE1RM: Double

  public init(
    studentID: UUID,
    family: LiftFamily,
    decision: ImportedHistoryReviewDecision,
    reviewedMaxE1RM: Double
  ) {
    self.studentID = studentID
    self.family = family
    self.decision = decision
    self.reviewedMaxE1RM = reviewedMaxE1RM
  }
}

public struct PendingImportedHistoryReview: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentID: UUID
  public let family: LiftFamily
  public let pointIDs: Set<UUID>
  public let reviewedMaxE1RM: Double
  public let baseline1RMKg: Double
  public let sourceWeightKg: Double
  public let sourceReps: Int
  public let sourceE1RMKg: Double

  public init(
    id: UUID,
    studentID: UUID,
    family: LiftFamily,
    pointIDs: Set<UUID>,
    reviewedMaxE1RM: Double,
    baseline1RMKg: Double,
    sourceWeightKg: Double,
    sourceReps: Int,
    sourceE1RMKg: Double
  ) {
    self.id = id
    self.studentID = studentID
    self.family = family
    self.pointIDs = pointIDs
    self.reviewedMaxE1RM = reviewedMaxE1RM
    self.baseline1RMKg = baseline1RMKg
    self.sourceWeightKg = sourceWeightKg
    self.sourceReps = sourceReps
    self.sourceE1RMKg = sourceE1RMKg
  }
}

public protocol ImportedHistoryReviewStoring: Sendable {
  func review(studentID: UUID, family: LiftFamily) async throws -> ImportedHistoryReviewRecord?
  func pendingReview(
    studentID: UUID,
    family: LiftFamily
  ) async throws -> PendingImportedHistoryReview?
  func save(review: ImportedHistoryReviewRecord) async throws
  func save(pendingReview: PendingImportedHistoryReview) async throws
  func removePendingReview(studentID: UUID, family: LiftFamily) async throws
}

public actor LocalImportedHistoryReviewStore: ImportedHistoryReviewStoring {
  private struct Storage: Codable, Sendable {
    var reviews: [ImportedHistoryReviewRecord] = []
    var pendingReviews: [PendingImportedHistoryReview] = []
  }

  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private var cached: Storage?

  public init(directory: URL? = nil) {
    let base =
      directory
      ?? URL.documentsDirectory.appending(path: "e1rm", directoryHint: .isDirectory)
    fileURL = base.appending(path: "imported-history-reviews.json", directoryHint: .notDirectory)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    self.encoder = encoder
    decoder = JSONDecoder()
  }

  public func review(
    studentID: UUID,
    family: LiftFamily
  ) async throws -> ImportedHistoryReviewRecord? {
    try load().reviews.first { $0.studentID == studentID && $0.family == family }
  }

  public func pendingReview(
    studentID: UUID,
    family: LiftFamily
  ) async throws -> PendingImportedHistoryReview? {
    try load().pendingReviews.first { $0.studentID == studentID && $0.family == family }
  }

  public func save(review: ImportedHistoryReviewRecord) async throws {
    var storage = try load()
    storage.reviews.removeAll { $0.studentID == review.studentID && $0.family == review.family }
    storage.reviews.append(review)
    try save(storage)
  }

  public func save(pendingReview: PendingImportedHistoryReview) async throws {
    var storage = try load()
    storage.pendingReviews.removeAll {
      $0.studentID == pendingReview.studentID && $0.family == pendingReview.family
    }
    storage.pendingReviews.append(pendingReview)
    try save(storage)
  }

  public func removePendingReview(studentID: UUID, family: LiftFamily) async throws {
    var storage = try load()
    let previousCount = storage.pendingReviews.count
    storage.pendingReviews.removeAll { $0.studentID == studentID && $0.family == family }
    guard storage.pendingReviews.count != previousCount else { return }
    try save(storage)
  }

  private func load() throws -> Storage {
    if let cached { return cached }
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      let storage = Storage()
      cached = storage
      return storage
    }

    let storage = try decoder.decode(Storage.self, from: Data(contentsOf: fileURL))
    cached = storage
    return storage
  }

  private func save(_ storage: Storage) throws {
    cached = storage
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try encoder.encode(storage).write(to: fileURL, options: .atomic)
  }
}

public actor InMemoryImportedHistoryReviewStore: ImportedHistoryReviewStoring {
  private var reviews: [ImportedHistoryReviewRecord]
  private var pendingReviews: [PendingImportedHistoryReview]

  public init(
    reviews: [ImportedHistoryReviewRecord] = [],
    pendingReviews: [PendingImportedHistoryReview] = []
  ) {
    self.reviews = reviews
    self.pendingReviews = pendingReviews
  }

  public func review(
    studentID: UUID,
    family: LiftFamily
  ) async throws -> ImportedHistoryReviewRecord? {
    reviews.first { $0.studentID == studentID && $0.family == family }
  }

  public func pendingReview(
    studentID: UUID,
    family: LiftFamily
  ) async throws -> PendingImportedHistoryReview? {
    pendingReviews.first { $0.studentID == studentID && $0.family == family }
  }

  public func save(review: ImportedHistoryReviewRecord) async throws {
    reviews.removeAll { $0.studentID == review.studentID && $0.family == review.family }
    reviews.append(review)
  }

  public func save(pendingReview: PendingImportedHistoryReview) async throws {
    pendingReviews.removeAll {
      $0.studentID == pendingReview.studentID && $0.family == pendingReview.family
    }
    pendingReviews.append(pendingReview)
  }

  public func removePendingReview(studentID: UUID, family: LiftFamily) async throws {
    pendingReviews.removeAll { $0.studentID == studentID && $0.family == family }
  }
}
