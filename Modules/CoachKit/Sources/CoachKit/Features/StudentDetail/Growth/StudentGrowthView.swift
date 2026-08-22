import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentGrowthView: View {
  private struct TrendPresentation {
    let symbol: String
    let color: Color
    let accessibilityLabel: String
  }

  let studentID: UUID
  let now: Date
  @Bindable private var viewModel: StudentGrowthViewModel

  init(
    studentID: UUID,
    now: Date,
    viewModel: StudentGrowthViewModel
  ) {
    self.studentID = studentID
    self.now = now
    self.viewModel = viewModel
  }

  var body: some View {
    ScrollView {
      Group {
        switch viewModel.state {
        case .idle, .loading:
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.top, MeetPRSpacing.point32)
        case .failed(let message):
          growthFailure(message)
        case .loaded:
          if LiftFamily.allCases.allSatisfy({ viewModel.points(for: $0).isEmpty }) {
            growthMessage(CoachGrowthStrings.empty)
          } else {
            growthContent
          }
        }
      }
      .padding(.horizontal, MeetPRSpacing.pageHorizontal)
      .padding(.bottom, MeetPRSpacing.point28)
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
    .task {
      await viewModel.loadIfNeeded(studentID: studentID, now: now)
    }
  }

  private var growthContent: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      totalCard
      ForEach(LiftFamily.allCases, id: \.self) { family in
        familyCard(family)
      }
    }
  }

  private var totalCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point7) {
      Text(CoachGrowthStrings.totalE1RM)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textDisabled)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space1) {
        Text(viewModel.latestTotal.map(number) ?? "—")
          .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
          .foregroundStyle(Color.MeetPR.inkOnCTAFill)
        Text("kg")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textDisabled)
      }
      ProgressView(value: totalProgress)
        .progressViewStyle(.linear)
        .tint(Color.MeetPR.inkOnCTAFill)
        .background(Color.MeetPR.inkOnCTAFill.opacity(0.14))
        .clipShape(.rect(cornerRadius: MeetPRRadius.micro))
        .frame(height: MeetPRSpacing.point5)
      HStack {
        Text(CoachGrowthStrings.totalProgress(percent(totalProgress)))
        Spacer()
        Text(CoachGrowthStrings.oneRMTotal(decimal(viewModel.oneRMTotal)))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
      }
      .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      .foregroundStyle(Color.MeetPR.textDisabled)
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.textPrimary)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  private func familyCard(_ family: LiftFamily) -> some View {
    let points = viewModel.points(for: family)
    return VStack(alignment: .leading, spacing: MeetPRSpacing.point6) {
      Text(CoachGrowthStrings.familyTitle(family))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textSecondary)
      HStack(alignment: .lastTextBaseline) {
        if let headline = viewModel.headlineE1RM(for: family) {
          Text(number(headline))
            .font(.MeetPR.display(size: MeetPRFontMetrics.size30))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("kg")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textTertiary)
        } else {
          Text(CoachGrowthStrings.noFamilyData)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textTertiary)
        }
        Spacer()
        if let trend = trendPresentation(viewModel.trend(for: family)) {
          Text(trend.symbol)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size16, weight: .bold))
            .foregroundStyle(trend.color)
            .accessibilityLabel(trend.accessibilityLabel)
        }
      }
      if !points.isEmpty {
        E1RMChart(
          points: points.map {
            E1RMChartPoint(
              id: $0.id,
              date: $0.date,
              e1RMKg: NSDecimalNumber(decimal: $0.e1RMKg).doubleValue
            )
          }
        )
        .frame(height: 90)
      }
    }
    .padding(MeetPRSpacing.point15)
    .meetPRCardSurface(.card)
  }

  private func growthMessage(_ message: String) -> some View {
    Text(message)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
      .foregroundStyle(Color.MeetPR.textTertiary)
      .frame(maxWidth: .infinity)
      .padding(.top, MeetPRSpacing.point32)
  }

  private func growthFailure(_ message: String) -> some View {
    VStack(spacing: MeetPRSpacing.point10) {
      Text(message)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textTertiary)
        .multilineTextAlignment(.center)
      Button(CoachDetailStrings.retry) {
        Task { await viewModel.load(studentID: studentID, now: now) }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, MeetPRSpacing.point32)
  }

  private var totalProgress: Double {
    let goal = NSDecimalNumber(decimal: viewModel.oneRMTotal).doubleValue
    guard goal > 0, let latestTotal = viewModel.latestTotal else { return 0 }
    let latest = NSDecimalNumber(decimal: latestTotal).doubleValue
    return min(max(latest / goal, 0), 1)
  }

  private func number(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).doubleValue.formatted(
      .number.precision(.fractionLength(0...1))
    )
  }

  private func decimal(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).doubleValue.formatted(
      .number.precision(.fractionLength(0...1))
    )
  }

  private func percent(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
  }

  private func trendPresentation(
    _ trend: CoachExerciseStatsSnapshot.Trend?
  ) -> TrendPresentation? {
    switch trend {
    case .upward:
      TrendPresentation(
        symbol: "↑",
        color: Color.MeetPR.success,
        accessibilityLabel: CoachGrowthStrings.trendUp
      )
    case .steady:
      TrendPresentation(
        symbol: "→",
        color: Color.MeetPR.textTertiary,
        accessibilityLabel: CoachGrowthStrings.trendFlat
      )
    case .downward:
      TrendPresentation(
        symbol: "↓",
        color: Color.MeetPR.danger,
        accessibilityLabel: CoachGrowthStrings.trendDown
      )
    case .new:
      nil
    case .unknown, nil:
      nil
    }
  }
}

enum CoachGrowthStrings {
  static let totalE1RM = CoachLocalization.localized("coach.growth.totalE1RM")
  static let empty = CoachLocalization.localized("coach.growth.empty")
  static let loadFailed = CoachLocalization.localized("coach.growth.error.load")
  static let noFamilyData = CoachLocalization.localized("coach.growth.noFamilyData")
  static let trendUp = CoachLocalization.localized("coach.growth.trend.up")
  static let trendFlat = CoachLocalization.localized("coach.growth.trend.flat")
  static let trendDown = CoachLocalization.localized("coach.growth.trend.down")

  static func familyTitle(_ family: LiftFamily) -> String {
    switch family {
    case .squat: CoachLocalization.localized("coach.growth.family.squat")
    case .bench: CoachLocalization.localized("coach.growth.family.bench")
    case .deadlift: CoachLocalization.localized("coach.growth.family.deadlift")
    }
  }

  static func totalProgress(_ percent: String) -> String {
    CoachLocalization.localized("coach.growth.totalProgress \(percent)")
  }

  static func oneRMTotal(_ total: String) -> String {
    CoachLocalization.localized("coach.growth.oneRMTotal \(total)")
  }
}
