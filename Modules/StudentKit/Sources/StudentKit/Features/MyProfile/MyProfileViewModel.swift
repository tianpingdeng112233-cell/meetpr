import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class MyProfileViewModel {
  public enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded(OnboardingProfile)
    /// 404 — profile never filled (self-train scenario, spec 032 D10):
    /// the nine-card section shows the unlock placeholder.
    case empty
    case failed
  }

  public private(set) var state: State = .idle
  public private(set) var isFailed = false
  public private(set) var saveError: String?

  private let repo: any OnboardingRepository
  private let studentId: UUID
  private var loadRevision = 0

  public init(studentId: UUID, repo: any OnboardingRepository) {
    self.studentId = studentId
    self.repo = repo
  }

  public func loadIfNeeded() async {
    guard state == .idle else { return }
    await reload()
  }

  public func reload() async {
    loadRevision += 1
    let revision = loadRevision
    let previousState = state
    let previouslyFailed = isFailed
    if state == .idle { state = .loading }
    isFailed = false
    do {
      let profile = try await repo.fetchProfile(studentId: studentId)
      guard revision == loadRevision else { return }
      if let profile {
        state = .loaded(profile)
      } else {
        state = .empty
      }
    } catch {
      guard revision == loadRevision else { return }
      if error.isTaskCancellation {
        state = previousState
        isFailed = previouslyFailed
        return
      }
      isFailed = true
      if case .loaded = state { return }  // keep showing the last snapshot
      state = .failed
    }
  }

  /// Card-edit save: PUT the card's patch, then re-fetch so the summaries
  /// reflect the server's truth (spec 032 D10). Returns false to keep the
  /// edit page up.
  public func save(_ patch: OnboardingPatch) async -> Bool {
    await saveChanges(archivePatch: patch, todaysWeight: nil)
  }

  func saveCard(
    _ patch: OnboardingPatch, kind: ProfileCardKind, originalWeight: Decimal?
  ) async -> Bool {
    guard kind == .weight || kind == .basics else { return await save(patch) }
    var archivePatch = patch
    archivePatch.weightKg = .absent
    let weight: Decimal?
    if case .value(let value) = patch.weightKg,
      kind == .weight || value != originalWeight
    {
      weight = value
    } else {
      weight = nil
    }
    return await saveChanges(
      archivePatch: kind == .weight ? nil : archivePatch, todaysWeight: weight)
  }

  private func saveChanges(archivePatch: OnboardingPatch?, todaysWeight: Decimal?) async -> Bool {
    saveError = nil
    do {
      if let archivePatch { _ = try await repo.upsert(archivePatch) }
      if let todaysWeight {
        guard let weights = repo as? any BodyWeightRepository else {
          throw BodyWeightError.unavailable
        }
        _ = try await weights.saveTodaysWeight(todaysWeight)
        BodyWeightChanges.post(studentID: studentId)
      }
      await reload()
      return true
    } catch OnboardingError.oneRMLocked {
      // Structurally unreachable: card patches never carry 1RM fields
      // (spec 032 risk 6) — graceful toast just in case.
      saveError = StudentStrings.localized(.myProfileViewModel001)
      return false
    } catch {
      saveError = StudentStrings.localized(.myProfileViewModel002)
      return false
    }
  }
}
