import CoreModels
import RepositoryContracts
import SwiftUI

/// Wraps the solo student root behind a one-shot onboarding probe
/// (spec 046 §2): no profile or incomplete → the 2-screen flow; completed →
/// straight through. Solo never sees the BindGate (spec 031 D4).
@available(iOS 17.0, macOS 14.0, *)
public struct SoloOnboardingGateView<Content: View>: View {
  private enum GateState {
    case probing
    case needsOnboarding
    case ready
  }

  private let studentId: UUID
  private let onboarding: any OnboardingRepository
  private let content: () -> Content
  @State private var gate: GateState = .probing

  public init(
    studentId: UUID,
    onboarding: any OnboardingRepository,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.studentId = studentId
    self.onboarding = onboarding
    self.content = content
  }

  /// Fetch failure reads as "needs onboarding" (BindGate probe idiom): the
  /// flow is skippable, so the worst case is one extra harmless trip.
  static func needsOnboarding(_ profile: OnboardingProfile?) -> Bool {
    profile?.isCompleted != true
  }

  public var body: some View {
    switch gate {
    case .probing:
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
          let profile = try? await onboarding.fetchProfile(studentId: studentId)
          gate = Self.needsOnboarding(profile) ? .needsOnboarding : .ready
        }
    case .needsOnboarding:
      SoloOnboardingFlow(repository: onboarding) {
        gate = .ready
      }
    case .ready:
      content()
    }
  }
}
