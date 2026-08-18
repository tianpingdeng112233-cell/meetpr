import CoreModels
import DesignSystem
import SwiftUI

/// Two-step pre-workout check-in (spec 030 §C5). Step 1: three 5-dot scales
/// (all must be picked). Step 2: fatigued muscle chips with a tap-to-cycle
/// severity (轻→中→重→off); none selected is a legal answer.
@available(iOS 17.0, macOS 14.0, *)
struct ReadinessCheckinSheet: View {
  let studentID: UUID
  let viewModel: ReadinessCheckinViewModel
  let onClose: () -> Void

  @State private var draft: ReadinessDraft
  @State private var step = 1
  @State private var submitting = false

  init(
    studentID: UUID,
    viewModel: ReadinessCheckinViewModel,
    prefill: ReadinessCheckin? = nil,
    onClose: @escaping () -> Void
  ) {
    self.studentID = studentID
    self.viewModel = viewModel
    self.onClose = onClose
    self._draft = State(initialValue: prefill.map(ReadinessDraft.init(from:)) ?? ReadinessDraft())
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          if step == 1 {
            stepOne
          } else {
            stepTwo
          }
        }
        .padding(MeetPRSpacing.md)
      }
      .background(Color.MeetPR.bgBase)
      .navigationTitle(StudentStrings.replacing(.readinessCheckinSheet001, values: ["\(step)"]))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(StudentStrings.localized(.readinessCheckinSheet002)) {
            viewModel.skip(studentId: studentID)
            onClose()
          }
          .foregroundStyle(Color.MeetPR.textMuted)
        }
      }
      .safeAreaInset(edge: .bottom) {
        footer
          .padding(MeetPRSpacing.md)
          .background(Color.MeetPR.bgBase)
      }
    }
    .interactiveDismissDisabled()
  }

  // MARK: - Step 1

  private var stepOne: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      scaleRow(
        title: StudentStrings.localized(.readinessCheckinSheet003),
        lowAnchor: StudentStrings.localized(.readinessCheckinSheet004),
        highAnchor: StudentStrings.localized(.readinessCheckinSheet005),
        value: $draft.sleepQuality
      )
      scaleRow(
        title: StudentStrings.localized(.readinessCheckinSheet006),
        lowAnchor: StudentStrings.localized(.readinessCheckinSheet007),
        highAnchor: StudentStrings.localized(.readinessCheckinSheet008),
        value: $draft.mood
      )
      // Data stays 5 = most relaxed; only the anchor copy inverts.
      scaleRow(
        title: StudentStrings.localized(.readinessCheckinSheet009),
        lowAnchor: StudentStrings.localized(.readinessCheckinSheet010),
        highAnchor: StudentStrings.localized(.readinessCheckinSheet011),
        value: $draft.stress
      )
    }
  }

  private func scaleRow(
    title: String,
    lowAnchor: String,
    highAnchor: String,
    value: Binding<Int?>
  ) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      HStack(spacing: MeetPRSpacing.sm) {
        Text(lowAnchor)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
          .frame(width: 56, alignment: .leading)
        ForEach(1...5, id: \.self) { level in
          Button {
            value.wrappedValue = level
          } label: {
            Circle()
              .fill(
                (value.wrappedValue ?? 0) >= level
                  ? Color.MeetPR.gold500 : Color.MeetPR.surfaceElevated
              )
              .frame(width: 30, height: 30)
              .overlay(
                Circle().strokeBorder(
                  value.wrappedValue == level ? Color.MeetPR.bgBase : .clear,
                  lineWidth: 2
                )
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            StudentStrings.replacing(.readinessCheckinSheet012, values: ["\(title)", "\(level)"]))
        }
        Text(highAnchor)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
          .frame(width: 56, alignment: .trailing)
      }
    }
  }

  // MARK: - Step 2

  private var stepTwo: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      Text(StudentStrings.localized(.readinessCheckinSheet013))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(StudentStrings.localized(.readinessCheckinSheet014))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)

      FlowChips(
        groups: ReadinessCheckin.allowedMuscleGroups,
        severity: { draft.fatigue[$0] },
        onTap: { group in
          let next = ((draft.fatigue[group] ?? 0) + 1) % 4
          draft.fatigue[group] = next == 0 ? nil : next
        }
      )

      if let error = viewModel.submitError {
        Label(error, systemImage: "exclamationmark.triangle")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.dangerMuted)
      }
    }
  }

  // MARK: - Footer

  private var footer: some View {
    HStack {
      if step == 2 {
        Button(StudentStrings.localized(.readinessCheckinSheet015)) { step = 1 }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.textMuted)
      }
      Spacer()
      if step == 1 {
        GoldCTA(
          StudentStrings.localized(.readinessCheckinSheet016),
          sub: nil,
          icon: .none,
          isDisabled: !draft.stepOneComplete,
          isFullWidth: false
        ) {
          step = 2
        }
      } else {
        GoldCTA(
          submitting
            ? StudentStrings.localized(.readinessCheckinSheet017)
            : StudentStrings.localized(.readinessCheckinSheet018),
          sub: nil,
          icon: .none,
          isDisabled: submitting,
          isLoading: submitting,
          isFullWidth: false
        ) {
          submitting = true
          Task {
            let success = await viewModel.submit(draft, studentId: studentID)
            submitting = false
            if success { onClose() }
          }
        }
      }
    }
  }
}

/// Wrapping chip grid for the 8 whitelisted groups; severity shown as dots.
@available(iOS 17.0, macOS 14.0, *)
private struct FlowChips: View {
  let groups: [MuscleGroup]
  let severity: (MuscleGroup) -> Int?
  let onTap: (MuscleGroup) -> Void

  private let columns = [GridItem(.adaptive(minimum: 92), spacing: MeetPRSpacing.xs)]

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: MeetPRSpacing.xs) {
      ForEach(groups, id: \.self) { group in
        let level = severity(group)
        Button {
          onTap(group)
        } label: {
          VStack(spacing: 2) {
            Text(Self.displayName(group))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            Text(level.map { String(repeating: "·", count: $0) } ?? " ")
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          }
          .padding(.horizontal, MeetPRSpacing.sm)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity)
          .background(
            level == nil ? Color.MeetPR.surfaceCard : Color.MeetPR.goldRGB.opacity(0.12)
          )
          .foregroundStyle(level == nil ? Color.MeetPR.textMuted : Color.MeetPR.goldText)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
          .overlay(
            RoundedRectangle(cornerRadius: MeetPRRadius.md)
              .strokeBorder(
                level == nil
                  ? Color.MeetPR.borderDefault
                  : Color.MeetPR.goldRGB.opacity(0.4),
                lineWidth: 1
              )
          )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          StudentStrings.replacing(
            .readinessCheckinSheet019, values: ["\(Self.displayName(group))", "\(level ?? 0)"]))
      }
    }
  }

  /// Chinese display for the 8 whitelisted groups (full catalog mapping lives
  /// coach-side; StudentKit only ever shows these eight).
  private static func displayName(_ group: MuscleGroup) -> String {
    switch group {
    case .quad: StudentStrings.localized(.readinessCheckinSheet020)
    case .hamstring: StudentStrings.localized(.readinessCheckinSheet021)
    case .glute: StudentStrings.localized(.readinessCheckinSheet022)
    case .back: StudentStrings.localized(.readinessCheckinSheet023)
    case .chest: StudentStrings.localized(.readinessCheckinSheet024)
    case .shoulder: StudentStrings.localized(.readinessCheckinSheet025)
    case .triceps: StudentStrings.localized(.readinessCheckinSheet026)
    case .core: StudentStrings.localized(.readinessCheckinSheet027)
    default: group.rawValue
    }
  }
}
