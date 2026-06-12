import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Tab 5 "我的" (spec 028 §6 + spec 032 §7): growth-curve entry on top,
/// then the nine-card onboarding archive.
@available(iOS 17.0, macOS 14.0, *)
public struct MyProfileView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let evaluationSummaryViewModel: StudentEvaluationSummaryViewModel?
  /// nil hides the row (demo/previews); live wiring passes Session.logout.
  private let onLogout: (@MainActor () async -> Void)?
  @State private var viewModel: MyProfileViewModel

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: any OnboardingRepository,
    evaluationSummaryViewModel: StudentEvaluationSummaryViewModel? = nil,
    onLogout: (@MainActor () async -> Void)? = nil
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.evaluationSummaryViewModel = evaluationSummaryViewModel
    self.onLogout = onLogout
    self._viewModel = State(
      initialValue: MyProfileViewModel(studentId: studentID, repo: onboarding))
  }

  public var body: some View {
    NavigationStack {
      List {
        NavigationLink {
          GrowthCurveView(studentID: studentID, plans: plans, e1rm: e1rm)
        } label: {
          Label("成长曲线", systemImage: "chart.xyaxis.line")
            .font(Font.MeetPR.body)
        }
        .listRowBackground(Color.MeetPR.surface1)

        // Permanent evaluation-summary entry (spec 033 §12, wiki §5.5):
        // visible once a summary exists, with the unread red dot.
        if let evaluationSummaryViewModel,
          let summary = evaluationSummaryViewModel.summary
        {
          NavigationLink {
            EvaluationSummaryView(summary: summary) {
              evaluationSummaryViewModel.markRead()
            }
          } label: {
            HStack {
              Label("评估总结", systemImage: "doc.text")
                .font(Font.MeetPR.body)
              if evaluationSummaryViewModel.isUnread {
                Circle()
                  .fill(Color.MeetPR.brandRed)
                  .frame(width: 8, height: 8)
              }
            }
          }
          .listRowBackground(Color.MeetPR.surface1)
        }

        archiveSection

        if let onLogout {
          LogoutSection(onLogout: onLogout)
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
      .navigationTitle("我的")
      .refreshable {
        await viewModel.reload()
      }
    }
    .task {
      await viewModel.loadIfNeeded()
    }
  }

  @ViewBuilder
  private var archiveSection: some View {
    switch viewModel.state {
    case .idle, .loading:
      Section("我的资料") {
        HStack {
          ProgressView()
          Text("加载中")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
      .listRowBackground(Color.MeetPR.surface1)
    case .loaded(let profile):
      ProfileCardsSection(
        profile: profile,
        viewModel: viewModel,
        evaluationSummaryViewModel: evaluationSummaryViewModel
      )
    case .empty:
      // 404 — never filled in (self-train path, spec 032 D10).
      Section("我的资料") {
        Text("完成资料填写后解锁")
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .listRowBackground(Color.MeetPR.surface1)
    case .failed:
      Section("我的资料") {
        Button {
          Task { await viewModel.reload() }
        } label: {
          Label("加载失败,点击重试", systemImage: "arrow.clockwise")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
      .listRowBackground(Color.MeetPR.surface1)
    }
  }
}

/// "退出登录" — mirrors the coach side's destructive logout treatment
/// (CoachMyProfileView), adapted to the List context.
@available(iOS 17.0, macOS 14.0, *)
private struct LogoutSection: View {
  let onLogout: @MainActor () async -> Void
  @State private var isLoggingOut = false

  var body: some View {
    Section {
      Button {
        isLoggingOut = true
        Task { await onLogout() }
      } label: {
        Label(
          isLoggingOut ? "退出中" : "退出登录",
          systemImage: "rectangle.portrait.and.arrow.right"
        )
        .font(Font.MeetPR.bodyEmphasis)
        .frame(maxWidth: .infinity)
      }
      .foregroundStyle(Color.MeetPR.brandRed)
      .disabled(isLoggingOut)
    }
    .listRowBackground(Color.MeetPR.brandRedSoft)
  }
}
