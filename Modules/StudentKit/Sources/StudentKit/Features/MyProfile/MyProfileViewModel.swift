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
  public private(set) var saveError: String?

  private let repo: any OnboardingRepository
  private let studentId: UUID

  public init(studentId: UUID, repo: any OnboardingRepository) {
    self.studentId = studentId
    self.repo = repo
  }

  public func loadIfNeeded() async {
    guard state == .idle else { return }
    await reload()
  }

  public func reload() async {
    if state == .idle { state = .loading }
    do {
      if let profile = try await repo.fetchProfile(studentId: studentId) {
        state = .loaded(profile)
      } else {
        state = .empty
      }
    } catch {
      if case .loaded = state { return }  // keep showing the last snapshot
      state = .failed
    }
  }

  /// Card-edit save: PUT the card's patch, then re-fetch so the summaries
  /// reflect the server's truth (spec 032 D10). Returns false to keep the
  /// edit page up.
  public func save(_ patch: OnboardingPatch) async -> Bool {
    saveError = nil
    do {
      _ = try await repo.upsert(patch)
      await reload()
      return true
    } catch OnboardingError.oneRMLocked {
      // Structurally unreachable: card patches never carry 1RM fields
      // (spec 032 risk 6) — graceful toast just in case.
      saveError = "1RM 已锁定,请联系教练修改"
      return false
    } catch {
      saveError = "保存失败,请重试"
      return false
    }
  }
}
