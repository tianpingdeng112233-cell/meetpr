import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GrowthE1RMDetailSheet: View {
  let detail: GrowthE1RMDetail
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
        HStack {
          Text(StudentStrings.localized(.e1rmSourceTitle))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size19, weight: .bold))
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textSecondary)
              .frame(width: 34, height: 34)
              .background(Color.MeetPR.surfaceRaised, in: .circle)
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(StudentStrings.localized(.e1rmSourceClose))
        }
        HStack(alignment: .firstTextBaseline) {
          Text(detail.date.formatted(date: .abbreviated, time: .omitted))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          Spacer()
          Text(sourceBadge)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size10, weight: .semibold))
            .foregroundStyle(Color.MeetPR.goldText)
            .padding(.horizontal, MeetPRSpacing.space2)
            .padding(.vertical, MeetPRSpacing.space1)
            .background(Color.MeetPR.gold500.opacity(0.1), in: .capsule)
        }
        HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space1) {
          Text(detail.point.e1RMKg.formatted(.number.precision(.fractionLength(1))))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size38, weight: .bold))
          Text("kg")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size15))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        .padding(.bottom, MeetPRSpacing.space1)

        block(.e1rmSourceLabel) {
          Text(sourceTitle)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
          if detail.setNumber == nil {
            note(.e1rmSourceMissingSet)
          }
        }
        block(.e1rmSourceRecord) {
          Text("\(number(detail.point.sourceWeightKg)) kg × \(detail.point.sourceReps)")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size22, weight: .semibold))
          rpeRow(.e1rmSourceStudentRPE, value: detail.point.sourceRPE)
          if let coachRPE = detail.point.sourceCoachRPE {
            rpeRow(.e1rmSourceCoachRPE, value: coachRPE)
          }
        }
        block(.e1rmSourceCalculation) {
          calculation
        }
        if detail.point.confidence == .low {
          note(.e1rmSourceLowNote)
        } else {
          note(.e1rmSourceNote)
        }
        if detail.point.origin == .imported {
          note(.e1rmSourceImportedNote)
        }
      }
      .padding(MeetPRSpacing.space5)
      .foregroundStyle(Color.MeetPR.textPrimary)
    }
    .background(Color.MeetPR.surfaceCard)
    .presentationDetents([.height(620), .large])
    .presentationDragIndicator(.visible)
    .presentationBackground(Color.MeetPR.surfaceCard)
  }

  private var sourceBadge: String {
    StudentStrings.localized(
      detail.point.confidence == .low
        ? .e1rmSourceLow
        : detail.point.origin == .imported ? .e1rmSourceImported : .e1rmSourceDailyBest
    )
  }

  private var sourceTitle: String {
    let name = detail.exerciseName ?? StudentStrings.localized(.e1rmSourceMissingExercise)
    guard let setNumber = detail.setNumber else { return name }
    return name + " · " + StudentStrings.replacing(.e1rmSourceSet, values: ["\(setNumber)"])
  }

  @ViewBuilder private var calculation: some View {
    switch detail.calculation {
    case .rts(let intensity):
      Text(
        StudentStrings.replacing(
          .e1rmSourceRTS,
          values: [
            "\(detail.point.sourceReps)", number(detail.point.effectiveSourceRPE ?? 0),
            number(intensity * 100),
          ])
      )
      .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textSecondary)
      equation("\(number(detail.point.sourceWeightKg)) ÷ \(number(intensity))")
    case .epley:
      note(.e1rmSourceEpley)
      equation("\(number(detail.point.sourceWeightKg)) × (1 + \(detail.point.sourceReps) ÷ 30)")
    case .unavailable:
      note(.e1rmSourceUnavailable)
    }
  }

  private func equation(_ expression: String) -> some View {
    Text(
      expression + " ≈ " + detail.point.e1RMKg.formatted(.number.precision(.fractionLength(1)))
        + " kg"
    )
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size16, weight: .semibold))
    .fixedSize(horizontal: false, vertical: true)
  }

  private func block<Content: View>(
    _ title: StudentStrings.Key, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Text(StudentStrings.localized(title))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.space3)
    .background(Color.MeetPR.surfaceRaised, in: .rect(cornerRadius: MeetPRRadius.control))
  }

  private func rpeRow(_ title: StudentStrings.Key, value: Double?) -> some View {
    HStack {
      Text(StudentStrings.localized(title))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Spacer()
      Text(value.map(number) ?? StudentStrings.localized(.e1rmSourceNoRPE))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
    }
    .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
  }

  private func note(_ key: StudentStrings.Key) -> some View {
    Text(StudentStrings.localized(key))
      .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      .foregroundStyle(Color.MeetPR.textMuted)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func number(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...4)))
  }
}
