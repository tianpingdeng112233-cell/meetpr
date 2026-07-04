import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Drives the solo 2-screen light onboarding (spec 046 §2): unit + optional
/// bodyweight, then a skippable big-3 baseline. Both exits write completedAt —
/// backend spec 013 lets solo complete with the unit alone, so skipping never
/// re-prompts on the next launch.
@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class SoloOnboardingViewModel {
  public enum Step: Equatable {
    case unit
    case baseline
  }

  public enum SubmitState: Equatable {
    case idle
    case submitting
    case failed(String)
  }

  public private(set) var step: Step = .unit
  public private(set) var state: SubmitState = .idle
  public var unitPreference: UnitPreference = .kg
  public var weightText = ""
  /// Wizard working copy — only the three 1RM fields are used here, so the
  /// baseline screen reuses Step3StrengthSection unchanged.
  public var draft = OnboardingDraft()

  private let repository: any OnboardingRepository
  private let onCompleted: @MainActor () -> Void

  public init(
    repository: any OnboardingRepository,
    onCompleted: @escaping @MainActor () -> Void
  ) {
    self.repository = repository
    self.onCompleted = onCompleted
  }

  public func advanceToBaseline() {
    step = .baseline
  }

  /// Both exits of the baseline screen. Skipping still completes — otherwise
  /// the gate would re-prompt every launch (spec 046 §2 跳过语义).
  public func finish(skippingBaseline: Bool) async {
    guard state != .submitting else { return }
    state = .submitting
    var patch = OnboardingPatch()
    patch.unitPreference = .value(unitPreference)
    if let weight = UnitDisplay.parseWeight(weightText, unit: unitPreference) {
      patch.weightKg = .value(weight)
    }
    if !skippingBaseline {
      if let squat = draft.squat1RMKg { patch.squat1RMKg = .value(squat) }
      if let bench = draft.bench1RMKg { patch.bench1RMKg = .value(bench) }
      if let deadlift = draft.deadlift1RMKg { patch.deadlift1RMKg = .value(deadlift) }
    }
    do {
      _ = try await repository.upsert(patch)
      _ = try await repository.complete()
      state = .idle
      onCompleted()
    } catch {
      state = .failed("保存失败,请检查网络后重试")
    }
  }
}
