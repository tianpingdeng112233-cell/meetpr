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
      .background(Color.MeetPR.bg)
      .navigationTitle("今日状态 \(step)/2")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("跳过") {
            viewModel.skip(studentId: studentID)
            onClose()
          }
          .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
      .safeAreaInset(edge: .bottom) {
        footer
          .padding(MeetPRSpacing.md)
          .background(Color.MeetPR.bg)
      }
    }
    .interactiveDismissDisabled()
  }

  // MARK: - Step 1

  private var stepOne: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      // 动机文案 (spec 051 §3): 走查 P1-4 — 学员不知道填这个给谁看。
      Text("教练会据此调整你的计划")
        .font(.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      scaleRow(
        title: "昨晚睡得怎么样？",
        lowAnchor: "很差",
        highAnchor: "很好",
        value: $draft.sleepQuality
      )
      scaleRow(
        title: "今天状态如何？",
        lowAnchor: "很糟",
        highAnchor: "很棒",
        value: $draft.mood
      )
      // Data stays 5 = most relaxed; only the anchor copy inverts.
      scaleRow(
        title: "今天压力大吗？",
        lowAnchor: "压力爆表",
        highAnchor: "很轻松",
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
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      HStack(spacing: MeetPRSpacing.sm) {
        Text(lowAnchor)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .frame(width: 56, alignment: .leading)
        ForEach(1...5, id: \.self) { level in
          Button {
            value.wrappedValue = level
          } label: {
            Circle()
              .fill(
                (value.wrappedValue ?? 0) >= level
                  ? Color.MeetPR.brandRed : Color.MeetPR.surface3
              )
              .frame(width: 30, height: 30)
              .overlay(
                Circle().strokeBorder(
                  value.wrappedValue == level ? Color.MeetPR.fgPrimary : .clear, lineWidth: 2)
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(title) \(level) 分")
        }
        Text(highAnchor)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .frame(width: 56, alignment: .trailing)
      }
    }
  }

  // MARK: - Step 2

  private var stepTwo: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      Text("今天哪些肌群还累？")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text("点一下：轻 → 中 → 重 → 取消。不累可以直接完成。")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

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
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.brandRed)
      }
    }
  }

  // MARK: - Footer

  private var footer: some View {
    HStack {
      if step == 2 {
        Button("上一步") { step = 1 }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.fgSecondary)
      }
      Spacer()
      if step == 1 {
        Button("下一步") { step = 2 }
          .buttonStyle(.borderedProminent)
          .tint(Color.MeetPR.brandRed)
          .disabled(!draft.stepOneComplete)
      } else {
        Button(submitting ? "提交中…" : "完成") {
          submitting = true
          Task {
            let success = await viewModel.submit(draft, studentId: studentID)
            submitting = false
            if success { onClose() }
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.MeetPR.brandRed)
        .disabled(submitting)
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
              .font(Font.MeetPR.footnote)
            Text(level.map { String(repeating: "·", count: $0) } ?? " ")
              .font(Font.MeetPR.monoLabel)
          }
          .padding(.horizontal, MeetPRSpacing.sm)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity)
          .background(level == nil ? Color.MeetPR.surface2 : Color.MeetPR.brandRedSoft)
          .foregroundStyle(level == nil ? Color.MeetPR.fgSecondary : Color.MeetPR.brandRed)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
          .overlay(
            RoundedRectangle(cornerRadius: MeetPRRadius.md)
              .strokeBorder(
                level == nil ? Color.MeetPR.border : Color.MeetPR.brandRed, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Self.displayName(group))，疲劳度 \(level ?? 0)")
      }
    }
  }

  /// Chinese display for the 8 whitelisted groups (full catalog mapping lives
  /// coach-side; StudentKit only ever shows these eight).
  private static func displayName(_ group: MuscleGroup) -> String {
    switch group {
    case .quad: "股四"
    case .hamstring: "腘绳"
    case .glute: "臀"
    case .back: "背"
    case .chest: "胸"
    case .shoulder: "肩"
    case .triceps: "肱三头"
    case .core: "核心·下背"
    default: group.rawValue
    }
  }
}
