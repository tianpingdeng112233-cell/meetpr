import CoreModels
import DesignSystem
import SwiftUI

/// Solo 今天 tab (spec 045 扫视态): one big start/continue CTA plus a glance
/// at what today already holds. The editing state lives in SoloSessionView.
@available(iOS 17.0, macOS 14.0, *)
struct SoloTodayView: View {
  @State private var viewModel: SoloSessionViewModel
  private let catalog: [Exercise]
  private let makeReviewViewModel: (() -> SessionReviewSubmitViewModel)?

  init(
    viewModel: SoloSessionViewModel,
    catalog: [Exercise],
    makeReviewViewModel: (() -> SessionReviewSubmitViewModel)? = nil
  ) {
    self._viewModel = State(initialValue: viewModel)
    self.catalog = catalog
    self.makeReviewViewModel = makeReviewViewModel
  }

  private var committedCount: Int {
    viewModel.drafts.filter(\.completed).count
  }

  private var todayExerciseNames: [String] {
    var seen: Set<String> = []
    return viewModel.drafts.filter(\.completed).compactMap { draft in
      seen.insert(draft.exerciseName).inserted ? draft.exerciseName : nil
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          if viewModel.unsyncedCount > 0 {
            Label("\(viewModel.unsyncedCount) 组未同步,恢复网络后自动上传", systemImage: "icloud.slash")
              .font(.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal)
          }

          if committedCount > 0 {
            VStack(alignment: .leading, spacing: 8) {
              Text("今天已记 \(committedCount) 组")
                .font(.headline)
              Text(todayExerciseNames.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Color.MeetPR.fgSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.MeetPR.surface1)
            .clipShape(.rect(cornerRadius: 12))
            .padding(.horizontal)
          } else {
            VStack(spacing: 8) {
              Text("练什么都行,先记下来")
                .font(.headline)
              Text("从动作库挑动作,记下重量和次数,成长曲线会替你记住")
                .font(.footnote)
                .foregroundStyle(Color.MeetPR.fgSecondary)
                .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
          }

          NavigationLink {
            SoloSessionView(
              viewModel: viewModel, catalog: catalog, makeReviewViewModel: makeReviewViewModel)
          } label: {
            Text(committedCount > 0 ? "继续训练" : "开始训练")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.MeetPR.brandRed)
          .padding(.horizontal)
          .accessibilityIdentifier("solo.startWorkout")
        }
        .padding(.vertical)
      }
      .navigationTitle("今天")
      .task {
        await viewModel.load()
      }
      .refreshable {
        await viewModel.load()
      }
      // 跨午夜日期锁 (P0-2): re-lock 「今天」when the day rolls over while the
      // app sits on this tab — but only if the home is idle, so a session
      // spanning midnight keeps recording into its start day.
      .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
        Task { await viewModel.refreshForDayChangeIfIdle() }
      }
    }
  }
}
