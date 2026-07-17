import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Spec 028 §6: per-family e1RM growth curve with time-window filtering.
/// Variation-level curves and the variation picker sheet are V0.1.x.
@available(iOS 17.0, macOS 14.0, *)
public struct GrowthCurveView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let onboarding: (any OnboardingProfileReading)?

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: (any OnboardingProfileReading)? = nil
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.onboarding = onboarding
  }

  public var body: some View {
    ScrollView {
      GrowthCurvePanelView(
        studentID: studentID,
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding
      )
      .padding(MeetPRSpacing.md)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("成长曲线")
  }
}

/// Embeddable e1RM growth panel without scroll view, navigation title, or page background.
@available(iOS 17.0, macOS 14.0, *)
struct GrowthCurvePanelView: View {
  private let studentID: UUID
  @State private var viewModel: GrowthCurveViewModel
  @State private var selectedPoint: E1RMHistoryPoint?

  init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: (any OnboardingProfileReading)? = nil
  ) {
    self.studentID = studentID
    self._viewModel = State(
      initialValue: GrowthCurveViewModel(
        plans: plans,
        e1rm: e1rm,
        onboarding: onboarding
      )
    )
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.md) {
      Picker("主项", selection: $viewModel.selectedFamily) {
        Text("深蹲").tag(LiftFamily.squat)
        Text("卧推").tag(LiftFamily.bench)
        Text("硬拉").tag(LiftFamily.deadlift)
      }
      .pickerStyle(.segmented)

      Picker("时间", selection: $viewModel.selectedWindow) {
        ForEach(GrowthCurveViewModel.TimeWindow.allCases, id: \.self) { window in
          Text(window.rawValue).tag(window)
        }
      }
      .pickerStyle(.segmented)

      chartSection()
    }
    .task {
      if viewModel.state == .idle {
        await viewModel.load(studentID: studentID)
      }
    }
    .sheet(item: $selectedPoint) { point in
      pointDetail(point)
        .presentationDetents([.fraction(0.3)])
    }
  }

  @ViewBuilder
  private func chartSection() -> some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 240)
    case .error(let message):
      ContentUnavailableView(
        "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
    case .loaded:
      if viewModel.visibleSmoothedSamples.isEmpty && viewModel.visibleRawEligiblePoints.isEmpty {
        ContentUnavailableView(
          "还没有数据点",
          systemImage: "chart.xyaxis.line",
          description: Text("至少打勾 1 组训练才有第一点")
        )
        .frame(minHeight: 240)
      } else {
        E1RMChart(
          smoothed: viewModel.visibleSmoothedSamples.map { sample in
            E1RMChartPoint(
              id: sample.sampleID,
              date: sample.date,
              e1RMKg: sample.valueKg,
              origin: chartOrigin(sample.winnerOrigin),
              confidence: chartConfidence(sample.winnerConfidence),
              winnerPointID: sample.winnerPointID
            )
          },
          rawEligible: viewModel.visibleRawEligiblePoints.compactMap { point in
            guard point.confidence == .low else { return nil }
            return E1RMChartPoint(
              id: point.id,
              date: point.computedAt,
              e1RMKg: point.e1RMKg,
              origin: chartOrigin(point.origin),
              confidence: chartConfidence(point.confidence)
            )
          },
          onSelect: { chartPoint in
            selectedPoint = viewModel.winnerPoint(forSampleID: chartPoint.id)
          }
        )
        .frame(height: 280)
        .padding(MeetPRSpacing.sm)
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
    }
  }

  private func pointDetail(_ point: E1RMHistoryPoint) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(point.computedAt, format: .dateTime.year().month().day().weekday())
        .font(Font.MeetPR.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      HStack(spacing: MeetPRSpacing.lg) {
        metric("重量", "\(StudentFormatting.kilograms(point.sourceWeightKg)) kg")
        metric("次数", "\(point.sourceReps)")
        metric("RPE", point.sourceRPE.map { StudentFormatting.kilograms($0) } ?? "—")
      }
      HStack {
        Text("e1RM")
          .font(Font.MeetPR.monoLabel)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Text("\(StudentFormatting.kilograms(point.e1RMKg)) kg")
          .font(Font.MeetPR.title2)
          .foregroundStyle(Color.MeetPR.brandRed)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.md)
    .background(Color.MeetPR.bg)
  }

  private func metric(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(Font.MeetPR.monoLabel)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Text(value)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
    }
  }

  private func chartOrigin(_ origin: E1RMPointOrigin) -> E1RMChartPointOrigin {
    switch origin {
    case .logged: .logged
    case .imported: .imported
    }
  }

  private func chartConfidence(_ confidence: E1RMConfidence) -> E1RMChartPointConfidence {
    switch confidence {
    case .normal: .normal
    case .low: .low
    }
  }
}
