import CoreModels
import DesignSystem
import SwiftUI

struct AccessoryLogCard: View {
  let exercise: TodayWorkoutPresentation.Exercise
  let viewModel: TodayWorkoutViewModel
  let unit: UnitPreference
  let previousLogs: [Int: StudentSetLog]
  let onEdit: (TodayWorkoutPresentation.Row) -> Void
  @State private var edits: [UUID: AccessoryRow] = [:]
  @State private var showsSkipped = false

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      AccessoryColumns {
        ForEach(
          [
            StudentStrings.localized(.accessorySet), StudentStrings.localized(.accessoryLast),
            UnitDisplay.weightUnitSuffix(unit).uppercased(),
            StudentStrings.localized(.setEntrySheet003), "RPE",
            StudentStrings.localized(.workoutCompletionFlowView003),
          ], id: \.self
        ) { label in
          Text(label)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
        }
      }
      ForEach(exercise.rows) { presentationRow in
        AccessoryLogRow(
          row: Binding(
            get: { row(for: presentationRow) },
            set: { edits[presentationRow.id] = $0 }),
          number: presentationRow.record.index,
          isSaving: viewModel.accessorySavingIDs.contains(presentationRow.id),
          isDisabled: viewModel.accessoryBatchInFlight || !viewModel.accessorySavingIDs.isEmpty,
          showsValidation: showsSkipped,
          onEdit: { onEdit(presentationRow) },
          onSave: {
            let input = row(for: presentationRow)
            Task { await viewModel.saveAccessoryRow(input) }
          }
        )
      }
      if showsSkipped {
        let count = AccessoryRow.selection(exercise.rows.map { row(for: $0) }).skipped.count
        if count > 0 {
          Text(
            StudentStrings.replacing(
              count == 1 ? .accessoryNeedsWeightOne : .accessoryNeedsWeightMany,
              values: [String(count)])
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.goldText)
          .accessibilityIdentifier("accessory.skipped")
        }
      }
      Label(StudentStrings.localized(.accessoryHint), systemImage: "video")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("accessory.hint")
      if exercise.rows.contains(where: { !$0.draft.completed && !$0.draft.failed }) {
        Button {
          showsSkipped = true
          let rows = exercise.rows.map { row(for: $0) }
          Task { _ = await viewModel.completeAccessoryRows(rows) }
        } label: {
          HStack {
            if viewModel.accessoryBatchInFlight { ProgressView() }
            Text(StudentStrings.localized(.accessoryCompleteAll))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
          .padding(.vertical, MeetPRSpacing.space2)
          .foregroundStyle(Color.MeetPR.bgBase)
          .background(Color.MeetPR.textPrimary, in: .capsule)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(viewModel.accessoryBatchInFlight || !viewModel.accessorySavingIDs.isEmpty)
        .accessibilityIdentifier("accessory.completeAll")
      }
    }
    .accessibilityIdentifier("accessory.card")
  }

  private func row(for row: TodayWorkoutPresentation.Row) -> AccessoryRow {
    var source = AccessoryRow(
      draft: row.draft, previous: previousLogs[row.draft.prescribed.setIndex], unit: unit,
      hasVideo: row.record.videoState != .none)
    if let edit = edits[row.id], edit.draft == source.draft, edit.unit == source.unit {
      source.input = edit.input
    }
    return source
  }
}

/// One allocation for the header and every row, including narrow phone widths.
struct AccessoryColumns: Layout {
  private let weights: [CGFloat] = [36, 56, 64, 44, 48, 40]
  private let gap = MeetPRSpacing.point3

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? weights.reduce(0, +)
    let columns = widths(width)
    let height =
      zip(subviews, columns).map {
        $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height
      }.max() ?? 0
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var x = bounds.minX
    for (subview, width) in zip(subviews, widths(bounds.width)) {
      subview.place(
        at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
        proposal: ProposedViewSize(width: width, height: bounds.height))
      x += width + gap
    }
  }

  private func widths(_ width: CGFloat) -> [CGFloat] {
    let available = max(0, width - gap * CGFloat(weights.count - 1))
    return weights.map { available * $0 / weights.reduce(0, +) }
  }
}
