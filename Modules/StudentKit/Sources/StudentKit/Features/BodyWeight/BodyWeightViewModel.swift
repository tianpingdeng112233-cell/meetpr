import Combine
import Foundation
import Observation

@Observable
@MainActor
final class BodyWeightViewModel {
  private(set) var records: [BodyWeightRecord] = []
  private(set) var isLoaded = false
  private(set) var isFailed = false
  private(set) var isLoading = false
  private(set) var deletingDate: String?
  private var failedDeletion: BodyWeightRecord?
  var deletionFailed: Bool { failedDeletion != nil }
  var range: GrowthTimeRange = .thirtyDays
  private let studentID: UUID
  private let repository: (any BodyWeightRepository)?
  private let now: () -> Date
  private var loadRevision = 0

  init(
    studentID: UUID, repository: (any BodyWeightRepository)?, now: @escaping () -> Date = Date.init
  ) {
    self.studentID = studentID
    self.repository = repository
    self.now = now
  }

  var presentation: BodyWeightPresentation {
    BodyWeightPresentation(records: records, range: range, now: now())
  }

  var menuValue: String? {
    if isFailed { return "—" }
    guard isLoaded else { return nil }
    return presentation.currentKg.map { BodyWeightInput.text(kg: $0, unit: .kg) + " kg" } ?? "—"
  }

  func load() async {
    loadRevision += 1
    let revision = loadRevision
    isLoading = true
    do {
      guard let repository else { throw BodyWeightError.unavailable }
      let fetched = try await repository.fetchBodyWeights()
      guard revision == loadRevision else { return }
      records = fetched
      isLoaded = true
      isFailed = false
    } catch {
      guard revision == loadRevision else { return }
      if !error.isTaskCancellation { isFailed = true }
    }
    isLoading = false
  }

  func retryDelete() async -> Bool {
    guard let failedDeletion else { return false }
    return await delete(failedDeletion)
  }

  func delete(_ record: BodyWeightRecord) async -> Bool {
    guard let repository, deletingDate == nil else { return false }
    deletingDate = record.recordedOn
    failedDeletion = nil
    loadRevision += 1
    defer { deletingDate = nil }
    do {
      _ = try await repository.deleteBodyWeight(on: record.recordedOn)
      records.removeAll { $0.recordedOn == record.recordedOn }
      BodyWeightChanges.post(studentID: studentID)
      await load()
      return true
    } catch {
      if !error.isTaskCancellation { failedDeletion = record }
      return false
    }
  }
}

/// Retained tabs reload the current profile after a successful weight mutation.
enum BodyWeightChanges {
  static let notification = Notification.Name("MeetPR.bodyWeightChanged")
  static var publisher: NotificationCenter.Publisher {
    NotificationCenter.default.publisher(for: notification)
  }

  @MainActor
  static func post(studentID: UUID) {
    NotificationCenter.default.post(name: notification, object: studentID)
  }
}
