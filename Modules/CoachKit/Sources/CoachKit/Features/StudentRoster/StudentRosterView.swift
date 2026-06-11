import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentRosterView: View {
  @Bindable private var viewModel: StudentRosterViewModel
  @Bindable private var queueViewModel: BindQueueViewModel
  private let context: CoachStudentDetailContext
  @State private var acceptTarget: CoachBindRequestItem?
  @State private var rejectTarget: CoachBindRequestItem?
  @State private var profileTarget: CoachBindRequestItem?

  init(
    viewModel: StudentRosterViewModel,
    queueViewModel: BindQueueViewModel,
    context: CoachStudentDetailContext
  ) {
    self.viewModel = viewModel
    self.queueViewModel = queueViewModel
    self.context = context
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("学员")
        .navigationDestination(item: $profileTarget) { item in
          StudentOnboardingProfileView(
            item: item,
            profiles: context.profiles,
            onAccept: { acceptTarget = item },
            onReject: { rejectTarget = item }
          )
        }
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              Task {
                await refreshAll()
              }
            } label: {
              Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("刷新学员")
          }
        }
    }
    .sheet(item: $acceptTarget) { item in
      AcceptBindRequestSheet(studentName: item.displayName) { skipEvaluation, skipReason in
        let accepted = await queueViewModel.accept(
          item, skipEvaluation: skipEvaluation, skipReason: skipReason)
        if accepted {
          profileTarget = nil
          await viewModel.refresh()
        }
        return accepted
      }
    }
    .confirmationDialog(
      "拒绝后学员会看到中性提示(不会显示拒绝原因),确定拒绝?",
      isPresented: rejectDialogBinding,
      titleVisibility: .visible
    ) {
      Button("拒绝", role: .destructive) {
        if let item = rejectTarget {
          Task {
            if await queueViewModel.reject(item) {
              profileTarget = nil
            }
          }
        }
      }
      Button("取消", role: .cancel) {}
    }
    .task {
      await viewModel.loadIfNeeded()
      await queueViewModel.loadIfNeeded()
    }
  }

  private var rejectDialogBinding: Binding<Bool> {
    Binding(
      get: { rejectTarget != nil },
      set: { isPresented in
        if !isPresented { rejectTarget = nil }
      }
    )
  }

  private func refreshAll() async {
    await viewModel.refresh()
    await queueViewModel.refresh()
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.MeetPR.bg)
    case .failed(let message):
      ContentUnavailableView(
        "加载失败",
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
      .background(Color.MeetPR.bg)
    case .loaded:
      if viewModel.rows.isEmpty && queueViewModel.pendingCount == 0 {
        ContentUnavailableView(
          "暂无学员",
          systemImage: "person.2",
          description: Text("接收新学员请求后会出现在这里")
        )
        .background(Color.MeetPR.bg)
      } else {
        rosterList
      }
    }
  }

  private var rosterList: some View {
    List {
      if queueViewModel.pendingCount > 0 {
        queueSection
      }

      rosterSection
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bg)
    .refreshable {
      await refreshAll()
    }
    .searchable(text: $viewModel.searchText, prompt: "搜索学员")
  }

  private var rosterSection: some View {
    Section {
      if viewModel.rows.isEmpty {
        Text("暂无学员,接收新学员请求后会出现在这里")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .listRowBackground(Color.clear)
      } else {
        ForEach(viewModel.filteredRows) { row in
          NavigationLink {
            StudentDetailView(summary: row.student, context: context)
          } label: {
            StudentRosterRow(row: row)
          }
        }
      }
    } header: {
      if queueViewModel.pendingCount > 0 {
        Text("学员")
      }
    }
  }

  private var queueSection: some View {
    Section {
      if let banner = queueViewModel.bannerMessage {
        Label(banner, systemImage: "exclamationmark.triangle")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.amber)
          .listRowBackground(Color.clear)
      }
      if let toast = queueViewModel.toastMessage {
        Label(toast, systemImage: "checkmark.circle")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.green)
          .listRowBackground(Color.clear)
      }
      ForEach(queueViewModel.items) { item in
        BindRequestCard(
          item: item,
          now: queueViewModel.now(),
          onViewProfile: { profileTarget = item },
          onAccept: { acceptTarget = item },
          onReject: { rejectTarget = item }
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }
    } header: {
      Text("新学员请求 (\(queueViewModel.pendingCount))")
    }
  }
}
