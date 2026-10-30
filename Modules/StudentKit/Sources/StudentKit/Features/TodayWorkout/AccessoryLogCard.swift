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
  @State private var effortModeOverride: ActualEffortMode?
  @State private var showsSkipped = false
  @State private var attemptedRows: Set<UUID> = []

  private var allowsRIR: Bool { exercise.rows.allSatisfy { $0.draft.isAccessory } }
  private var effortMode: ActualEffortMode {
    effortModeOverride ?? exercise.rows.first(where: { $0.draft.loggedSetID == nil }).map {
      row(for: $0).input.effortMode
    } ?? exercise.rows.first.map { row(for: $0).input.effortMode } ?? .rpe
  }

  private func switchEffort() {
    let mode: ActualEffortMode = effortMode == .rpe ? .rir : .rpe
    for presentationRow in exercise.rows where presentationRow.draft.loggedSetID == nil {
      var input = row(for: presentationRow)
      input.switchEffort(to: mode)
      edits[presentationRow.id] = input
    }
    effortModeOverride = mode
  }

  private var hasBodyweight: Bool {
    exercise.rows.contains { $0.draft.prescribed.isBodyweight }
  }

  private var hasUniformLoadTypePrescription: Bool {
    guard let first = exercise.prescribedRows.first?.draft.prescribed else { return false }
    return exercise.prescribedRows.allSatisfy {
      let set = $0.draft.prescribed
      return set.loadMode == first.loadMode && set.isBodyweight == first.isBodyweight
        && set.reps == first.reps && set.repsMax == first.repsMax
        && set.intensity == first.intensity
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      if hasBodyweight {
        if hasUniformLoadTypePrescription, let first = exercise.prescribedRows.first {
          LoadTypePrescriptionHeader(
            set: first.draft.prescribed, count: exercise.prescribedRows.count)
        }
        Text(
          StudentStrings.replacing(
            .loadTypeExtraWeight, values: [UnitDisplay.weightUnitSuffix(unit)])
        )
        .font(.caption)
        .foregroundStyle(Color.MeetPR.textSecondary)
      }
      if allowsRIR || exercise.rows.contains(where: { $0.draft.prescribed.loadMode != .freeWeight })
      {
        AccessoryColumns {
          ForEach(
            [
              StudentStrings.localized(.accessorySet), StudentStrings.localized(.accessoryLast),
              UnitDisplay.weightUnitSuffix(unit).uppercased(),
              StudentStrings.localized(.setEntrySheet003), effortMode.label,
              StudentStrings.localized(.workoutCompletionFlowView003),
            ], id: \.self
          ) { label in
            Group {
              if label == effortMode.label && allowsRIR {
                Button(action: switchEffort) { EffortToggleLabel(text: label) }
                  .buttonStyle(.plain)
                  .frame(minHeight: MeetPRSpacing.minimumHitTarget)
                  .accessibilityLabel(StudentStrings.localized(.accessoryEffortSwitch))
                  .disabled(
                    viewModel.accessoryBatchInFlight || !viewModel.accessorySavingIDs.isEmpty
                      || !exercise.rows.contains(where: { $0.draft.loggedSetID == nil }))
              } else {
                Text(label)
              }
            }
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
          }
        }
      }
      ForEach(exercise.rows) { presentationRow in
        if presentationRow.draft.prescribed.loadMode == .freeWeight && !allowsRIR {
          if presentationRow.id == exercise.rows.first?.id || !hasUniformLoadTypePrescription {
            LoadTypePrescriptionHeader(
              set: presentationRow.draft.prescribed,
              count: hasUniformLoadTypePrescription ? exercise.prescribedRows.count : 1)
          }
          LoadTypeLogRow(
            row: Binding(
              get: { row(for: presentationRow) }, set: { edits[presentationRow.id] = $0 }),
            number: presentationRow.record.index,
            isSaving: viewModel.accessorySavingIDs.contains(presentationRow.id),
            isDisabled: viewModel.accessoryBatchInFlight || !viewModel.accessorySavingIDs.isEmpty,
            showsValidation: showsSkipped || attemptedRows.contains(presentationRow.id),
            onEdit: { onEdit(presentationRow) },
            onSave: {
              attemptedRows.insert(presentationRow.id)
              let input = row(for: presentationRow)
              guard input.isWritable || input.isCancellation else { return }
              Task { await viewModel.saveAccessoryRow(input) }
            })
          if let note = row(for: presentationRow).extraNote {
            Text(note).font(.caption).foregroundStyle(Color.MeetPR.coachNoteText)
          }
        } else {
          if presentationRow.draft.prescribed.loadMode == .freeWeight && allowsRIR {
            if presentationRow.id == exercise.rows.first?.id || !hasUniformLoadTypePrescription {
              LoadTypePrescriptionHeader(
                set: presentationRow.draft.prescribed,
                count: hasUniformLoadTypePrescription ? exercise.prescribedRows.count : 1)
            }
          }
          if presentationRow.draft.prescribed.isBodyweight && !hasUniformLoadTypePrescription {
            LoadTypePrescriptionHeader(set: presentationRow.draft.prescribed, count: 1)
          }
          AccessoryLogRow(
            row: Binding(
              get: { row(for: presentationRow) },
              set: { edits[presentationRow.id] = $0 }),
            number: presentationRow.record.index,
            columnEffortMode: effortMode,
            isSaving: viewModel.accessorySavingIDs.contains(presentationRow.id),
            isDisabled: viewModel.accessoryBatchInFlight || !viewModel.accessorySavingIDs.isEmpty,
            showsValidation: showsSkipped || attemptedRows.contains(presentationRow.id),
            onEdit: { onEdit(presentationRow) },
            onSave: {
              attemptedRows.insert(presentationRow.id)
              let input = row(for: presentationRow)
              Task { await viewModel.saveAccessoryRow(input) }
            }
          )
        }
        if presentationRow.draft.isExtra {
          HStack {
            Spacer()
            RemoveStudentSetButton(row: presentationRow, viewModel: viewModel)
          }
        }
      }
      ForEach(
        exercise.rows.filter {
          (showsSkipped || attemptedRows.contains($0.id))
            && $0.draft.prescribed.loadMode == .freeWeight && row(for: $0).weightKg == nil
        }
      ) { row in
        Text(StudentStrings.replacing(.loadTypeMissingWeight, values: [String(row.record.index)]))
          .font(.caption)
          .foregroundStyle(Color.MeetPR.danger)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("accessory.set.\(row.record.index).weightError")
      }
      ExtraSetControls(
        exercise: exercise, viewModel: viewModel, editable: true, onEdit: onEdit,
        showsRows: false)
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
      if exercise.rows.contains(where: {
        !$0.draft.completed && !$0.draft.failed && !$0.draft.isExtra
      }) {
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
      draft: row.draft,
      previous: row.draft.isExtra ? nil : previousLogs[row.draft.prescribed.setIndex],
      unit: row.draft.prescribed.loadMode == .freeWeight && !allowsRIR ? .kg : unit,
      hasVideo: row.record.videoState != .none)
    if let edit = edits[row.id], edit.draft == source.draft, edit.unit == source.unit {
      source.input = edit.input
    } else if let effortModeOverride, source.draft.loggedSetID == nil {
      source.switchEffort(to: effortModeOverride)
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

/// A compact visible control with the surrounding button retaining its touch target.
struct EffortToggleLabel: View {
  let text: String
  var body: some View {
    Text(text)
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .padding(.horizontal, MeetPRSpacing.space2)
      .padding(.vertical, MeetPRSpacing.space1)
      .background(Color.MeetPR.surfaceRaised, in: .rect(cornerRadius: MeetPRRadius.micro))
      .overlay(
        RoundedRectangle(cornerRadius: MeetPRRadius.micro).strokeBorder(
          Color.MeetPR.borderStrong, lineWidth: 1))
  }
}
