import CoreModels
import DesignSystem
import Foundation
import Observation
import RepositoryContracts
import SwiftUI

protocol E1RMCompetitionLiftRunning: Sendable {
  func runIfNeeded(studentID: UUID) async throws -> E1RMCompetitionLiftMigration.Result
}

@Observable
@MainActor
final class E1RMCompetitionLiftGateViewModel {
  enum State: Equatable {
    case idle
    case migrating
    case ready
    case failed
  }

  private(set) var state: State = .idle
  @ObservationIgnored private let migration: any E1RMCompetitionLiftRunning

  init(migration: any E1RMCompetitionLiftRunning) {
    self.migration = migration
  }

  func migrate(studentID: UUID) async {
    guard state != .migrating, state != .ready else { return }
    state = .migrating
    do {
      _ = try await migration.runIfNeeded(studentID: studentID)
      state = .ready
    } catch {
      state = .failed
    }
  }
}

/// Blocks every authenticated student destination until the one-shot e1RM
/// rebuild succeeds. Both the evaluation-period flow and the normal tab root
/// sit below this gate in AppShell.
@available(iOS 17.0, macOS 14.0, *)
public struct E1RMCompetitionLiftGate<Content: View>: View {
  private let studentID: UUID
  private let content: Content
  @State private var viewModel: E1RMCompetitionLiftGateViewModel

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    onboarding: any OnboardingProfileReading,
    e1rm: any E1RMRepository,
    @ViewBuilder content: () -> Content
  ) {
    let migration = E1RMCompetitionLiftMigration(
      logs: logs,
      onboarding: onboarding,
      plans: plans,
      catalogReader: plans as? any ExerciseCatalogReading,
      e1rm: e1rm
    )
    self.studentID = studentID
    self.content = content()
    self._viewModel = State(
      initialValue: E1RMCompetitionLiftGateViewModel(migration: migration)
    )
  }

  public var body: some View {
    Group {
      switch viewModel.state {
      case .ready:
        content
      case .failed:
        VStack(spacing: MeetPRSpacing.md) {
          Text(StudentStrings.localized(.e1RmcompetitionLiftGate001))
            .font(.MeetPR.display(size: MeetPRFontMetrics.size20))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(StudentStrings.localized(.e1RmcompetitionLiftGate002))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.dangerMuted)
            .multilineTextAlignment(.center)
          GoldCTA(
            StudentStrings.localized(.e1RmcompetitionLiftGate003), sub: nil, icon: .none,
            isFullWidth: false
          ) {
            Task { await viewModel.migrate(studentID: studentID) }
          }
        }
        .padding(MeetPRSpacing.base)
      case .idle, .migrating:
        ProgressView(StudentStrings.localized(.e1RmcompetitionLiftGate004))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .task {
      await viewModel.migrate(studentID: studentID)
    }
  }
}
