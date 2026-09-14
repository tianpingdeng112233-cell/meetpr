// swiftlint:disable file_length
import CoreModels
import DesignSystem
import SwiftUI

/// The keypad's own field enum doubles as the row's editable column.
typealias QuickLogField = MeetPRNumberPad.Field

extension MeetPRNumberPad.Field {
  fileprivate var quickLogTitle: String {
    switch self {
    case .weight: StudentStrings.localized(.quickLog018)
    case .reps: StudentStrings.localized(.quickLog019)
    case .rpe: StudentStrings.localized(.quickLog010)
    }
  }
}

private struct QuickLogActiveCell: Equatable, Identifiable {
  let rowID: UUID
  let field: QuickLogField
  var id: String { "\(rowID.uuidString)-\(field)" }
}

private struct QuickLogFailureAlert: Identifiable {
  let id = UUID()
  let message: String
}

private struct QuickLogExerciseItem: Identifiable {
  let sequenceNumber: Int
  let exercise: StudentPlanExercise
  var id: UUID { exercise.id }
}

@available(iOS 17.0, macOS 14.0, *)
struct QuickLogSheet: View {
  let day: StudentPlanDay
  let weekCode: String
  let viewModel: TodayWorkoutViewModel
  let onSuccess: () -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var plan: QuickLogPlan
  @State private var activeCell: QuickLogActiveCell?
  @State private var failureAlert: QuickLogFailureAlert?
  @State private var isSubmitting = false

  init(
    day: StudentPlanDay,
    weekCode: String,
    plan: QuickLogPlan,
    viewModel: TodayWorkoutViewModel,
    onSuccess: @escaping () -> Void
  ) {
    self.day = day
    self.weekCode = weekCode
    self.viewModel = viewModel
    self.onSuccess = onSuccess
    _plan = State(initialValue: plan)
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      QuickLogNavigationBar(
        weekCode: weekCode,
        dayName: TrainingSequenceText.dayName(day),
        isDismissDisabled: isSubmitting,
        onDismiss: { dismiss() }
      )

      ScrollView {
        VStack(spacing: MeetPRSpacing.space3) {
          QuickLogDateRow(plan: $plan)
          ForEach(orderedExercises) { item in
            QuickLogExerciseCard(
              sequenceNumber: item.sequenceNumber,
              rows: rows(for: item.exercise.id),
              activeRowID: activeCell?.rowID,
              activeField: activeCell?.field,
              onSelect: { rowID, field in
                activeCell = QuickLogActiveCell(rowID: rowID, field: field)
              },
              onToggle: toggleRow,
              onRestore: {
                plan.setExerciseIncluded(true, planExerciseID: item.exercise.id)
              }
            )
          }
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.space4)
        .padding(.bottom, MeetPRSpacing.space5)
      }
      .scrollIndicators(.hidden)
    }
    .background(Color.MeetPR.bgBase)
    .safeAreaInset(edge: .bottom, spacing: MeetPRSpacing.zero) {
      QuickLogFooter(plan: plan, isSubmitting: isSubmitting, onSubmit: submit)
    }
    .overlay {
      if activeCell != nil {
        Button(
          action: { activeCell = nil },
          label: {
            Color.black.opacity(0.35)
              .ignoresSafeArea()
          }
        )
        .buttonStyle(.plain)
        .accessibilityHidden(true)
      }
    }
    .overlay(alignment: .bottom) {
      if let activeCell, let row = plan.rows.first(where: { $0.id == activeCell.rowID }) {
        numberPad(for: activeCell, row: row)
          .id(activeCell.id)
          .transition(.move(edge: .bottom))
      }
    }
    .animation(MeetPRMotion.spring, value: activeCell?.id)
    .interactiveDismissDisabled(isSubmitting)
    .alert(
      StudentStrings.localized(.quickLog022),
      isPresented: Binding(
        get: { failureAlert != nil },
        set: { if !$0 { failureAlert = nil } }
      )
    ) {
      Button(StudentStrings.localized(.quickLog025)) { submit() }
      Button(StudentStrings.localized(.quickLog026), role: .cancel) {}
    } message: {
      Text(failureAlert?.message ?? "")
    }
  }

  // Same order as the summary card and `makeDrafts` (plan order of
  // `day.exercises`); sorting by `sequenceIndex` here made the sheet disagree
  // with the card it was opened from.
  private var orderedExercises: [QuickLogExerciseItem] {
    day.exercises.enumerated().map {
      QuickLogExerciseItem(sequenceNumber: $0.offset + 1, exercise: $0.element)
    }
  }

  private func rows(for exerciseID: UUID) -> [QuickLogPlan.Row] {
    plan.rows.filter { $0.draft.planExerciseID == exerciseID }
  }

  private func toggleRow(_ rowID: UUID) {
    guard let row = plan.rows.first(where: { $0.id == rowID }) else { return }
    plan.setIncluded(!row.included, for: rowID)
    if activeCell?.rowID == rowID { activeCell = nil }
  }

  private func numberPad(
    for activeCell: QuickLogActiveCell,
    row: QuickLogPlan.Row
  ) -> some View {
    // "同步到全部" is a weight-only shortcut (⚖️2026-09-02): reps and RPE
    // never fan out across the exercise.
    let synchronize: (@MainActor (Double) -> Void)?
    if activeCell.field == .weight {
      synchronize = { value in
        apply(value, to: activeCell)
        plan.syncWeightToExercise(from: activeCell.rowID)
      }
    } else {
      synchronize = nil
    }

    return MeetPRNumberPad(
      field: activeCell.field,
      value: numberPadValue(activeCell.field, row: row),
      minimumWeight: row.draft.isAccessory ? 0 : 20,
      contextText: QuickLogCellLabel.text(for: row, field: activeCell.field),
      syncTitle: activeCell.field == .weight ? syncTitle(for: row) : nil,
      nextTitle: StudentStrings.localized(.quickLog021),
      commitTitle: StudentStrings.localized(.quickLog029),
      onCommit: { value in
        apply(value, to: activeCell)
        self.activeCell = nil
      },
      onSync: synchronize,
      onNext: { value in
        apply(value, to: activeCell)
        self.activeCell = nextCell(after: activeCell)
      },
      onCancel: { self.activeCell = nil }
    )
  }

  private func numberPadValue(_ field: QuickLogField, row: QuickLogPlan.Row) -> Double {
    switch field {
    case .weight: NSDecimalNumber(decimal: row.draft.actualWeight ?? 0).doubleValue
    case .reps: Double(row.draft.actualReps ?? 1)
    case .rpe: NSDecimalNumber(decimal: row.draft.actualRPE ?? 8).doubleValue
    }
  }

  private func syncTitle(for row: QuickLogPlan.Row) -> String {
    StudentStrings.replacing(
      .quickLog020,
      values: ["\(rows(for: row.draft.planExerciseID).count)"]
    )
  }

  private func apply(_ value: Double, to cell: QuickLogActiveCell) {
    switch cell.field {
    case .weight: plan.updateWeight(Decimal(value), for: cell.rowID)
    case .reps: plan.updateReps(Int(value), for: cell.rowID)
    case .rpe: plan.updateRPE(Decimal(value), for: cell.rowID)
    }
  }

  private func nextCell(after cell: QuickLogActiveCell) -> QuickLogActiveCell? {
    switch cell.field {
    case .weight:
      return QuickLogActiveCell(rowID: cell.rowID, field: .reps)
    case .reps:
      return QuickLogActiveCell(rowID: cell.rowID, field: .rpe)
    case .rpe:
      let included = plan.rows.filter(\.included)
      guard let index = included.firstIndex(where: { $0.id == cell.rowID }),
        included.indices.contains(index + 1)
      else { return nil }
      return QuickLogActiveCell(rowID: included[index + 1].id, field: .weight)
    }
  }

  private func submit() {
    guard plan.hasIncludedSets, !isSubmitting else { return }
    activeCell = nil
    isSubmitting = true
    Task {
      let outcome = await viewModel.quickLog(plan: plan)
      isSubmitting = false
      switch outcome {
      case .completed:
        onSuccess()
      case .noIncludedSets:
        break
      case .partialFailure(let writtenCount, _):
        failureAlert = QuickLogFailureAlert(
          message: StudentStrings.replacing(
            .quickLog023,
            values: ["\(plan.includedSetCount - writtenCount)", "\(writtenCount)"]
          )
        )
      case .completionFailed:
        viewModel.clearActionError()
        failureAlert = QuickLogFailureAlert(message: StudentStrings.localized(.quickLog024))
      }
    }
  }
}

// MARK: - Cell labels

/// "深蹲 · 第 1 组 · 重量 (kg)" — shared by the keypad header and the
/// accessibility label of each value cell.
private enum QuickLogCellLabel {
  static func text(for row: QuickLogPlan.Row, field: QuickLogField) -> String {
    StudentStrings.replacing(
      .quickLog017,
      values: [
        row.draft.displayExerciseName,
        "\(SetDisplayNumber.number(for: row.draft))",
        field.quickLogTitle,
      ]
    )
  }
}

// MARK: - Navigation bar

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogNavigationBar: View {
  let weekCode: String
  let dayName: String
  let isDismissDisabled: Bool
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      VStack(spacing: MeetPRSpacing.point2) {
        Text(StudentStrings.replacing(.quickLog003, values: [weekCode]))
          .font(.MeetPR.display(size: MeetPRFontMetrics.size17))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(dayName)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }

      HStack {
        Button(
          action: onDismiss,
          label: {
            Label(StudentStrings.localized(.quickLog002), systemImage: "chevron.left")
              .font(.MeetPR.body(size: MeetPRFontMetrics.size16))
              .foregroundStyle(Color.MeetPR.textPrimary)
              .frame(minHeight: MeetPRSpacing.minimumHitTarget)
          }
        )
        .buttonStyle(.plain)
        .disabled(isDismissDisabled)

        Spacer()
      }
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.top, MeetPRSpacing.space2)
  }
}

// MARK: - Date row

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogDateRow: View {
  @Binding var plan: QuickLogPlan

  var body: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(StudentStrings.localized(.quickLog004))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(
          StudentStrings.replacing(
            .quickLog005,
            values: [Self.dateText(plan.allowedDateRange.lowerBound, calendar: plan.calendar)]
          )
        )
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      }
      Spacer()
      ZStack {
        DatePicker(
          StudentStrings.localized(.quickLog004),
          selection: Binding(
            get: { plan.selectedDate },
            set: { plan.selectDate($0) }
          ),
          in: plan.allowedDateRange,
          displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        // Fully transparent but still hit-testable: `.opacity(0.01)` leaves the
        // system label ghosting through the capsule.
        .colorMultiply(.clear)

        Label(
          Self.dateText(plan.selectedDate, calendar: plan.calendar),
          systemImage: "calendar"
        )
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
      .padding(.horizontal, MeetPRSpacing.space3)
      .frame(minHeight: MeetPRSpacing.point40)
      .background(Color.MeetPR.surfaceKey, in: .capsule)
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.space3)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.inset)
        .stroke(Color.MeetPR.borderSubtle, lineWidth: MeetPRSpacing.point1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
  }

  private static func dateText(_ date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.month, .day], from: date)
    var weekdayStyle = Date.FormatStyle.dateTime.weekday(.short).locale(.current)
    weekdayStyle.timeZone = calendar.timeZone
    return "\(components.month ?? 0)/\(components.day ?? 0) \(date.formatted(weekdayStyle))"
  }
}

// MARK: - Footer

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogFooter: View {
  let plan: QuickLogPlan
  let isSubmitting: Bool
  let onSubmit: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      HStack(spacing: MeetPRSpacing.space2) {
        Image(systemName: "clock")
        Text(summaryText)
      }
      .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .medium))
      .foregroundStyle(Color.MeetPR.textSecondary)
      .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.point40)
      .overlay {
        Capsule()
          .stroke(
            Color.MeetPR.borderStrong,
            style: StrokeStyle(
              lineWidth: MeetPRSpacing.point1AndHalf,
              dash: [MeetPRSpacing.space1]
            )
          )
      }

      HoldToCompleteButton(
        action: onSubmit,
        title: StudentStrings.localized(.quickLog016),
        accessibilityLabel: StudentStrings.localized(.quickLog016),
        isEnabled: plan.hasIncludedSets,
        isLoading: isSubmitting
      )
    }
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.top, MeetPRSpacing.space3)
    .padding(.bottom, MeetPRSpacing.space2)
    .background(Color.MeetPR.bgBase)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: MeetPRSpacing.point1)
    }
  }

  private var summaryText: String {
    guard plan.hasIncludedSets else { return StudentStrings.localized(.quickLog015) }
    return StudentStrings.replacing(
      .quickLog014,
      values: ["\(plan.includedExerciseCount)", "\(plan.includedSetCount)"]
    )
  }
}

// MARK: - Exercise card

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogExerciseCard: View {
  let sequenceNumber: Int
  let rows: [QuickLogPlan.Row]
  let activeRowID: UUID?
  let activeField: QuickLogField?
  let onSelect: (UUID, QuickLogField) -> Void
  let onToggle: (UUID) -> Void
  let onRestore: () -> Void

  private var includedCount: Int { rows.count(where: \.included) }
  private var displayName: String { rows.first?.draft.displayExerciseName ?? "" }

  var body: some View {
    if includedCount == 0 {
      Button(
        action: onRestore,
        label: {
          QuickLogCollapsedExerciseRow(
            displayName: displayName,
            sequenceNumber: sequenceNumber,
            setCount: rows.count
          )
        }
      )
      .buttonStyle(.plain)
    } else {
      VStack(spacing: MeetPRSpacing.space2) {
        QuickLogExerciseHeader(
          sequenceNumber: sequenceNumber,
          displayName: displayName,
          prescriptionText: rows.first.map { prescriptionText(for: $0.draft.prescribed) },
          includedCount: includedCount,
          setCount: rows.count
        )
        QuickLogColumnHeaders()
        VStack(spacing: MeetPRSpacing.point6) {
          ForEach(rows) { row in
            QuickLogSetRow(
              row: row,
              isActive: activeRowID == row.id ? activeField : nil,
              onSelect: { onSelect(row.id, $0) },
              onToggle: { onToggle(row.id) }
            )
          }
        }
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.vertical, MeetPRSpacing.point14)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.card)
          .stroke(Color.MeetPR.borderSubtle, lineWidth: MeetPRSpacing.point1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    }
  }

  private func prescriptionText(for set: PrescribedSet) -> String {
    var text = StudentFormatting.prescribed(set).replacing(" x ", with: " × ")
    if !text.localizedStandardContains("RPE"), let rpe = set.rpe {
      text += " · RPE \(StudentFormatting.decimal(rpe))"
    }
    return text
  }
}

// MARK: - Exercise header

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogExerciseHeader: View {
  let sequenceNumber: Int
  let displayName: String
  let prescriptionText: String?
  let includedCount: Int
  let setCount: Int

  var body: some View {
    HStack(spacing: MeetPRSpacing.point10) {
      Text("\(sequenceNumber)")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(width: MeetPRSpacing.point22, height: MeetPRSpacing.point22)
        .background(
          Color.MeetPR.goldRGB.opacity(0.12),
          in: .rect(cornerRadius: MeetPRRadius.micro)
        )
      Text(displayName)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineLimit(1)
      if let prescriptionText {
        Text(StudentStrings.replacing(.quickLog006, values: [prescriptionText]))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      Spacer(minLength: MeetPRSpacing.space1)
      Text(StudentStrings.replacing(.quickLog007, values: ["\(includedCount)", "\(setCount)"]))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
        .foregroundStyle(Color.MeetPR.success)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogColumnHeaders: View {
  var body: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      Text("#").frame(width: MeetPRSpacing.space6, alignment: .leading)
      Text(StudentStrings.localized(.quickLog008)).frame(maxWidth: .infinity, alignment: .leading)
      Text(StudentStrings.localized(.quickLog009)).frame(maxWidth: .infinity, alignment: .leading)
      Text(StudentStrings.localized(.quickLog010)).frame(maxWidth: .infinity, alignment: .leading)
      Text(StudentStrings.localized(.quickLog011)).frame(width: MeetPRSpacing.point32)
    }
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
    .foregroundStyle(Color.MeetPR.textFaint)
    .accessibilityHidden(true)
  }
}

// MARK: - Set row

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogSetRow: View {
  let row: QuickLogPlan.Row
  let isActive: QuickLogField?
  let onSelect: (QuickLogField) -> Void
  let onToggle: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      Text("\(SetDisplayNumber.number(for: row.draft))")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(width: MeetPRSpacing.space6, alignment: .leading)
      metric(
        StudentFormatting.decimal(row.draft.actualWeight),
        unit: "kg",
        field: .weight,
        showsAutomatic: row.usesAutomaticWeight
      )
      metric(row.draft.actualReps.map(String.init) ?? "—", unit: nil, field: .reps)
      metric(StudentFormatting.decimal(row.draft.actualRPE), unit: nil, field: .rpe)
      Button(
        action: onToggle,
        label: {
          Image(systemName: row.included ? "checkmark.circle.fill" : "circle")
            .font(.system(size: MeetPRSpacing.point26, weight: .semibold))
            .foregroundStyle(row.included ? Color.MeetPR.success : Color.MeetPR.borderStrong)
            .frame(width: MeetPRSpacing.point32, height: MeetPRSpacing.minimumHitTarget)
        }
      )
      .buttonStyle(.plain)
      .accessibilityLabel(StudentStrings.localized(.quickLog011))
      .accessibilityValue("\(SetDisplayNumber.number(for: row.draft))")
      .accessibilityAddTraits(row.included ? .isSelected : [])
    }
    .opacity(row.included ? 1 : 0.45)
    .strikethrough(!row.included)
  }

  private func metric(
    _ value: String,
    unit: String?,
    field: QuickLogField,
    showsAutomatic: Bool = false
  ) -> some View {
    Button(
      action: { onSelect(field) },
      label: {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.point3) {
          Text(value)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
          if let unit {
            Text(unit)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
              .foregroundStyle(Color.MeetPR.textSecondary)
          }
          if showsAutomatic {
            Text(StudentStrings.localized(.quickLog012))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size9))
              .foregroundStyle(Color.MeetPR.goldText)
          }
        }
        .foregroundStyle(showsAutomatic ? Color.MeetPR.textSecondary : Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget, alignment: .leading)
        .padding(.horizontal, MeetPRSpacing.space2)
        .background(
          isActive == field ? Color.MeetPR.goldRGB.opacity(0.1) : Color.MeetPR.surfaceKey
        )
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.control)
            .stroke(
              isActive == field ? Color.MeetPR.gold500 : Color.clear,
              lineWidth: MeetPRSpacing.point1AndHalf
            )
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      }
    )
    .buttonStyle(.plain)
    .disabled(!row.included)
    .accessibilityLabel(QuickLogCellLabel.text(for: row, field: field))
    .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
  }
}

// MARK: - Collapsed exercise

@available(iOS 17.0, macOS 14.0, *)
private struct QuickLogCollapsedExerciseRow: View {
  let displayName: String
  let sequenceNumber: Int
  let setCount: Int

  var body: some View {
    HStack(spacing: MeetPRSpacing.point10) {
      Text("\(sequenceNumber)")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
        .foregroundStyle(Color.MeetPR.textFaint)
        .frame(width: MeetPRSpacing.point22, height: MeetPRSpacing.point22)
        .background(Color.MeetPR.bgStack, in: .rect(cornerRadius: MeetPRRadius.micro))
      Text(displayName)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textFaint)
        .strikethrough()
      Spacer()
      Text(StudentStrings.replacing(.quickLog013, values: ["\(setCount)"]))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textFaint)
      Image(systemName: "circle")
        .font(.system(size: MeetPRSpacing.point26))
        .foregroundStyle(Color.MeetPR.borderStrong)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.borderSubtle, lineWidth: MeetPRSpacing.point1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}
