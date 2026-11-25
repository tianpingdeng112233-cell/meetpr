import CoreModels
import DesignSystem
import SwiftUI

struct CycleOutlookSheet: View {
  let model: TodayWorkoutViewModel
  let onSelect: (UUID) -> Void
  @State private var outlook: CycleOutlookPlan?
  @State private var failed = false
  @State private var scrollWeek: Int?
  @Environment(\.locale) private var locale
  @ScaledMetric(relativeTo: .caption) private var columnWidth = 56.0
  @ScaledMetric(relativeTo: .caption) private var rowHeight = 172.0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
        HStack(alignment: .firstTextBaseline) {
          Text(StudentStrings.localized(.cycleTitle, locale: locale)).font(.headline)
          Spacer(minLength: MeetPRSpacing.space2)
          if let outlook {
            Text(weekSummary(outlook))
              .font(.caption)
              .foregroundStyle(
                outlook.scheduledWeeks < outlook.totalWeeks
                  ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
          }
        }
        if let outlook {
          GeometryReader { geometry in
            let gap = MeetPRSpacing.space1
            let width =
              outlook.totalWeeks <= 5
              ? max(
                0,
                (geometry.size.width - gap * CGFloat(outlook.totalWeeks - 1))
                  / CGFloat(outlook.totalWeeks))
              : columnWidth
            ZStack(alignment: .topLeading) {
              ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: gap) {
                  ForEach(0..<outlook.totalWeeks, id: \.self) { index in
                    VStack(spacing: MeetPRSpacing.zero) {
                      ForEach(outlook.rows) { row in
                        CycleOutlookBar(cell: row.cells[index], onSelect: onSelect)
                          .frame(width: width, height: rowHeight, alignment: .bottom)
                      }
                    }
                    .id(index)
                  }
                }
                .scrollTargetLayout()
              }
              .scrollIndicators(.hidden)
              .scrollPosition(id: $scrollWeek, anchor: .leading)
              VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
                ForEach(outlook.rows) { row in
                  Text(row.id.studentDisplayName)
                    .font(.subheadline.bold())
                    .frame(height: rowHeight, alignment: .top)
                }
              }
              .allowsHitTesting(false)
            }
          }
          .frame(height: rowHeight * CGFloat(outlook.rows.count))
        } else if failed {
          ProgressRetryRow(onRetry: { Task { await load() } })
        } else {
          ProgressView().frame(maxWidth: .infinity, minHeight: MeetPRSpacing.point64)
        }
        Spacer(minLength: MeetPRSpacing.zero)
      }
    }
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.top, MeetPRSpacing.space6)
    .foregroundStyle(Color.MeetPR.textPrimary)
    .background(Color.MeetPR.surfaceCard)
    .task { await load() }
    .presentationDetents([.fraction(0.78), .large])
    .presentationDragIndicator(.visible)
  }

  private func weekSummary(_ outlook: CycleOutlookPlan) -> String {
    let weeks = String(outlook.totalWeeks)
    if outlook.scheduledWeeks < outlook.totalWeeks {
      return StudentStrings.replacing(
        .cycleScheduled, values: [String(outlook.scheduledWeeks), weeks], locale: locale)
    }
    let name = outlook.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let summary = StudentStrings.replacing(
      .handoffPlanWeeks, values: [name, weeks], locale: locale)
    return name.isEmpty ? String(summary.drop(while: { $0.isWhitespace || $0 == "·" })) : summary
  }

  private func load() async {
    failed = false
    do {
      let result = try await model.makeCycleOutlook(locale: locale)
      outlook = result
      scrollWeek = result.initialWeekIndex
    } catch {
      if !error.isTaskCancellation { failed = true }
    }
  }
}

private struct CycleOutlookBar: View {
  let cell: CycleOutlookCell
  let onSelect: (UUID) -> Void
  @Environment(\.locale) private var locale

  @ScaledMetric(relativeTo: .caption) private var chartHeight = 112.0

  var body: some View {
    Button {
      if let dayID = cell.dayID { onSelect(dayID) }
    } label: {
      VStack(spacing: MeetPRSpacing.space1) {
        VStack(spacing: MeetPRSpacing.space1) {
          Text(cell.main)
            .font(.caption.monospacedDigit().bold())
            .foregroundStyle(cell.isTop ? Color.MeetPR.goldText : Color.MeetPR.textPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
          CycleOutlookReps(cell: cell)
          CycleOutlookColumn(cell: cell)
            .frame(
              height: cell.state == .notTrained
                ? 2 : cell.state == .unscheduled ? 20 : 12 + 60 * cell.ratio)
        }
        .frame(minHeight: chartHeight, alignment: .bottom)
        HStack(spacing: MeetPRSpacing.zero) {
          if cell.done {
            Image(systemName: "checkmark").foregroundStyle(Color.MeetPR.goldText)
          }
          Text("W\(cell.id + 1)")
          if cell.isCurrent { Text(" " + StudentStrings.localized(.cycleCurrent, locale: locale)) }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(cell.isTop ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
        .lineLimit(1).minimumScaleFactor(0.5)
        .frame(height: MeetPRSpacing.space5)
      }
      .padding(.bottom, MeetPRSpacing.space3)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(cell.dayID == nil)
    .accessibilityLabel("W\(cell.id + 1), \(cell.main), \(cell.sub)")
  }
}

private struct CycleOutlookReps: View {
  let cell: CycleOutlookCell
  var body: some View {
    let sub = cell.sub
    Group {
      if let reps = cell.shortReps {
        Text("×") + Text(reps).foregroundStyle(Color.MeetPR.danger)
          + Text(String(sub.dropFirst(reps.count + 1)))
      } else {
        Text(sub.isEmpty ? " " : sub)
      }
    }
    .font(.caption2.monospacedDigit())
    .foregroundStyle(Color.MeetPR.textMuted)
    .lineLimit(1)
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct CycleOutlookColumn: View {
  let cell: CycleOutlookCell
  var body: some View {
    UnevenRoundedRectangle(
      topLeadingRadius: MeetPRRadius.point6, topTrailingRadius: MeetPRRadius.point6
    )
    .fill(fill)
    .overlay {
      if cell.isCurrent || cell.state == .unscheduled {
        UnevenRoundedRectangle(
          topLeadingRadius: MeetPRRadius.point6, topTrailingRadius: MeetPRRadius.point6
        )
        .stroke(
          cell.isCurrent ? Color.MeetPR.goldRGB : Color.MeetPR.textMuted,
          style: StrokeStyle(lineWidth: 1.5, dash: cell.state == .unscheduled ? [4, 3] : []))
      }
    }
  }
  private var fill: AnyShapeStyle {
    if cell.state == .unscheduled { return AnyShapeStyle(Color.clear) }
    if cell.isTop {
      return AnyShapeStyle(
        LinearGradient(
          colors: [.MeetPR.goldGradientEnd, .MeetPR.gold500], startPoint: .top, endPoint: .bottom))
    }
    return AnyShapeStyle(
      cell.done ? Color.MeetPR.goldRGB.opacity(0.32) : Color.MeetPR.borderDefault)
  }
}
