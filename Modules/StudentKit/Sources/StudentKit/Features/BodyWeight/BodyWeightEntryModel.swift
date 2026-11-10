import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable @MainActor
final class BodyWeightEntryModel {
  private(set) var profile: OnboardingProfile?
  private(set) var records: [BodyWeightRecord] = []
  private(set) var isSaving = false
  private(set) var saveFailed = false
  var isPresented = false
  var previewText = ""
  private let studentID: UUID
  private let onboarding: any OnboardingRepository
  private var revision = 0

  init(studentID: UUID, onboarding: any OnboardingRepository) {
    self.studentID = studentID
    self.onboarding = onboarding
  }

  var latest: BodyWeightRecord? { records.max { $0.recordedOn < $1.recordedOn } }

  func load() async {
    revision += 1
    let request = revision
    do {
      let fetchedProfile = try await onboarding.fetchProfile(studentId: studentID)
      guard request == revision, !Task.isCancelled else { return }
      profile = fetchedProfile
    } catch {
      // A failed refresh must not erase the last loaded meet or weight.
    }
    guard request == revision, !Task.isCancelled else { return }
    do {
      if let repository = onboarding as? any BodyWeightRepository {
        let fetchedRecords = try await repository.fetchBodyWeights()
        guard request == revision, !Task.isCancelled else { return }
        records = fetchedRecords
      }
    } catch {
      // Keep the last successful records available while offline.
    }
  }

  func open() {
    saveFailed = false
    previewText = Self.inputText(latest?.weightKg ?? profile?.weightKg)
    isPresented = true
  }

  static func inputText(_ kilograms: Decimal?) -> String {
    kilograms.map {
      $0.formatted(
        .number.locale(Locale(identifier: "en_US_POSIX"))
          .precision(.fractionLength(1)).grouping(.never))
    } ?? ""
  }

  func cancel() {
    guard !isSaving else { return }
    isPresented = false
    previewText = ""
  }

  static func kilograms(_ text: String) -> Decimal? {
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2, parts.count == 1 || parts[1].count <= 1 else { return nil }
    return UnitDisplay.parseWeight(text, unit: .kg)
  }

  func save(_ text: String) async -> Bool {
    guard !isSaving, let weight = Self.kilograms(text) else { return false }
    isSaving = true
    saveFailed = false
    defer { isSaving = false }
    do {
      if let repository = onboarding as? any BodyWeightRepository {
        _ = try await repository.saveTodaysWeight(weight)
      } else {
        var patch = OnboardingPatch()
        patch.weightKg = .value(weight)
        _ = try await onboarding.upsert(patch)
      }
      // Keep today's successful save visible even when the history API is unavailable (404 fallback).
      let today = BodyWeightDay.string(from: Date())
      records.removeAll { $0.recordedOn == today }
      records.append(BodyWeightRecord(recordedOn: today, weightKg: weight))
      isPresented = false
      BodyWeightChanges.post(studentID: studentID)
      await load()
      return true
    } catch {
      saveFailed = !error.isTaskCancellation
      return false
    }
  }
}
