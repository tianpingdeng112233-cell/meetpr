import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentGrowthView: View {
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
          growthMessage(message)
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
      HStack {
        Text(CoachGrowthStrings.totalE1RM)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textDisabled)
        Spacer()
        if let gain = totalGain {
          Text(signed(gain))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .bold))
            .foregroundStyle(Color.MeetPR.success)
        }
      }
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space1) {
        Text(number(viewModel.latestTotal))
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
        if let latest = points.last {
          Text(number(latest.e1RMKg))
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
        if let gain = viewModel.gain(for: family) {
          Text(signed(gain))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.success)
        }
      }
      if !points.isEmpty {
        E1RMChart(
          points: points.map {
            E1RMChartPoint(id: $0.id, date: $0.date, e1RMKg: $0.e1RMKg)
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

  private var totalGain: Double? {
    let gains = LiftFamily.allCases.compactMap(viewModel.gain(for:))
    return gains.isEmpty ? nil : gains.reduce(0, +)
  }

  private var totalProgress: Double {
    let goal = NSDecimalNumber(decimal: viewModel.oneRMTotal).doubleValue
    guard goal > 0 else { return 0 }
    return min(max(viewModel.latestTotal / goal, 0), 1)
  }

  private func number(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
  }

  private func decimal(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).doubleValue.formatted(
      .number.precision(.fractionLength(0...1))
    )
  }

  private func percent(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
  }

  private func signed(_ value: Double) -> String {
    let number = abs(value).formatted(.number.precision(.fractionLength(0...1)))
    return value >= 0 ? "+\(number)" : "−\(number)"
  }
}

enum CoachGrowthStrings {
  static let totalE1RM = CoachLocalization.localized("coach.growth.totalE1RM")
  static let empty = CoachLocalization.localized("coach.growth.empty")
  static let noFamilyData = CoachLocalization.localized("coach.growth.noFamilyData")

  static func familyTitle(_ family: LiftFamily) -> String {
    switch family {
    case .squat: CoachLocalization.localized("coach.growth.family.squat")
    case .bench: CoachLocalization.localized("coach.growth.family.bench")
    case .deadlift: CoachLocalization.localized("coach.growth.family.deadlift")
    }
  }

  static func totalProgress(_ percent: String) -> String {
    CoachLocalization.replacing(
      "coach.growth.totalProgress",
      values: ["percent": percent]
    )
  }

  static func oneRMTotal(_ total: String) -> String {
    CoachLocalization.replacing(
      "coach.growth.oneRMTotal",
      values: ["total": total]
    )
  }
}
