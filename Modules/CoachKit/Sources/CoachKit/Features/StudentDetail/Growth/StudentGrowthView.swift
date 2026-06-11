import CoreModels
import DesignSystem
import SwiftUI

/// Coach-side growth tab (spec 029 §2.7, second pass). Same visual contract
/// as the student-side curve — the chart atom lives in DesignSystem, the
/// data flow is CoachKit-local (CoachKit ⊥ StudentKit).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentGrowthView: View {
  let studentID: UUID
  @Bindable private var viewModel: StudentGrowthViewModel

  init(studentID: UUID, viewModel: StudentGrowthViewModel) {
    self.studentID = studentID
    self.viewModel = viewModel
  }

  var body: some View {
    ScrollView {
      VStack(spacing: MeetPRSpacing.md) {
        Picker("主项", selection: $viewModel.selectedFamily) {
          Text("深蹲").tag(LiftFamily.squat)
          Text("卧推").tag(LiftFamily.bench)
          Text("硬拉").tag(LiftFamily.deadlift)
        }
        .pickerStyle(.segmented)

        Picker("时间", selection: $viewModel.selectedWindow) {
          ForEach(StudentGrowthViewModel.TimeWindow.allCases, id: \.self) { window in
            Text(window.rawValue).tag(window)
          }
        }
        .pickerStyle(.segmented)

        chartSection
      }
      .padding(MeetPRSpacing.md)
    }
    .background(Color.MeetPR.bg)
    .task {
      await viewModel.loadIfNeeded(studentID: studentID)
    }
  }

  @ViewBuilder
  private var chartSection: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 240)
    case .failed(let message):
      ContentUnavailableView(
        "加载失败",
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
    case .loaded:
      if viewModel.visiblePoints.isEmpty {
        ContentUnavailableView(
          "还没有数据点",
          systemImage: "chart.xyaxis.line",
          description: Text("学员近 90 天完成主项训练后会出现曲线")
        )
        .frame(minHeight: 240)
      } else {
        E1RMChart(
          points: viewModel.visiblePoints.map {
            E1RMChartPoint(id: $0.id, date: $0.date, e1RMKg: $0.e1RMKg)
          }
        )
        .frame(height: 280)
        .padding(MeetPRSpacing.sm)
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
    }
  }
}
