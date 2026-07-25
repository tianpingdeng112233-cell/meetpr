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
          Text("实力记录校准失败")
            .font(Font.MeetPR.headline)
          Text("请重试，校准完成前不会使用旧的 e1RM 或 PR 基线。")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.textSecondary)
            .multilineTextAlignment(.center)
          PrimaryButton("重试") {
            Task { await viewModel.migrate(studentID: studentID) }
          }
        }
        .padding(MeetPRSpacing.base)
      case .idle, .migrating:
        ProgressView("正在校准实力记录…")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task {
      await viewModel.migrate(studentID: studentID)
    }
  }
}
