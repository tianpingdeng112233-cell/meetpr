import DesignSystem
import Foundation
import SwiftUI

enum WorkoutCompletionFlowPhase: String, Identifiable, Sendable {
  case celebration
  case review

  var id: String { rawValue }
}

@available(iOS 17.0, macOS 14.0, *)
struct WorkoutCompletionFlowView: View {
  let presentation: WorkoutCompletionPresentation
  let studentID: UUID
  let reflectionStore: any SessionReflectionStore
  let initialPhase: WorkoutCompletionFlowPhase
  let onFinish: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var phase: WorkoutCompletionFlowPhase
  @State private var didFinish = false

  init(
    presentation: WorkoutCompletionPresentation,
    studentID: UUID,
    reflectionStore: any SessionReflectionStore = UserDefaultsSessionReflectionStore(),
    initialPhase: WorkoutCompletionFlowPhase = .celebration,
    onFinish: @escaping () -> Void
  ) {
    self.presentation = presentation
    self.studentID = studentID
    self.reflectionStore = reflectionStore
    self.initialPhase = initialPhase
    self.onFinish = onFinish
    self._phase = State(initialValue: initialPhase)
  }

  var body: some View {
    ZStack {
      switch phase {
      case .celebration:
        WorkoutCelebrationView(
          presentation: presentation,
          onOpenReview: { phase = .review },
          onFinish: finish
        )
        .transition(.opacity)
      case .review:
        SessionSummaryView(
          presentation: presentation,
          studentID: studentID,
          reflectionStore: reflectionStore,
          onComplete: finish
        )
        .transition(.opacity)
      }
    }
    .animation(reduceMotion ? nil : MeetPRMotion.screen, value: phase)
    .background(Color.MeetPR.bgBase)
    .interactiveDismissDisabled()
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }

  private func finish() {
    guard !didFinish else { return }
    didFinish = true
    onFinish()
    dismiss()
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct WorkoutCelebrationView: View {
  let presentation: WorkoutCompletionPresentation
  let onOpenReview: () -> Void
  let onFinish: () -> Void

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color.MeetPR.bgBase
        CelebrationBottomGlow(size: proxy.size)

        VStack(spacing: 0) {
          Spacer(minLength: MeetPRSpacing.space4)

          CelebrationEffects()
            .frame(width: 220, height: 220)
            .frame(width: 110, height: 110)

          Text("今日训练完成")
            .font(.MeetPR.display(size: MeetPRFontMetrics.size26))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .padding(.top, MeetPRSpacing.point22)
            .modifier(CompletionFade(delay: 0.14))

          CoachReceiptLine(text: presentation.coachReceiptText)
            .padding(.top, MeetPRSpacing.space3)
            .modifier(CompletionFade(delay: 0.24))

          HStack(spacing: 0) {
            CompletionHeroStat(
              value: presentation.weekCode,
              suffix: nil,
              label: presentation.weekDayLabel
            )
            .modifier(CompletionSlide(delay: 0.34))

            Rectangle()
              .fill(Color.MeetPR.surfaceRaised)
              .frame(width: 1)

            CompletionSetTicker(presentation: presentation)
              .modifier(CompletionSlide(delay: 0.47))
          }
          .frame(maxWidth: 300)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, MeetPRSpacing.point30)

          Text(presentation.metaText)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textMuted)
            .padding(.top, MeetPRSpacing.point18)
            .modifier(CompletionSlide(delay: 0.60))

          if let streak = presentation.streak {
            StreakCapsule(streak: streak)
              .padding(.top, MeetPRSpacing.point13)
              .modifier(CompletionSlide(delay: 0.73))
          }

          VStack(spacing: MeetPRSpacing.point14) {
            GoldCTA(
              "查看详细报告",
              sub: nil,
              icon: .none,
              showsShimmer: true,
              isFullWidth: false,
              action: onOpenReview
            )
            .accessibilityRepresentation {
              Button("查看详细报告", action: onOpenReview)
            }
            .padding(.horizontal, MeetPRSpacing.space6)

            Button("完成", action: onFinish)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
              .foregroundStyle(Color.MeetPR.textMuted)
              .frame(minWidth: MeetPRSpacing.minimumHitTarget, minHeight: 44)
              .buttonStyle(.plain)
          }
          .padding(.top, MeetPRSpacing.point34)
          .modifier(CompletionFade(delay: 0.82))

          Spacer(minLength: MeetPRSpacing.space4)
        }
        .padding(.horizontal, MeetPRSpacing.point28)
        .padding(.vertical, MeetPRSpacing.point32)
      }
    }
    .ignoresSafeArea()
  }
}

private struct CelebrationBottomGlow: View {
  let size: CGSize

  var body: some View {
    Ellipse()
      .fill(
        RadialGradient(
          stops: [
            .init(color: Color.MeetPR.goldRGB.opacity(0.20), location: 0),
            .init(color: Color.MeetPR.goldRGB.opacity(0.06), location: 0.48),
            .init(color: .clear, location: 0.72),
          ],
          center: .bottom,
          startRadius: 0,
          endRadius: size.width * 0.7
        )
      )
      .frame(width: size.width * 1.4, height: size.height * 0.7)
      .position(x: size.width / 2, y: size.height * 0.75)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
}

private struct CoachReceiptLine: View {
  let text: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Text("教")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size10, weight: .bold))
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(width: MeetPRSpacing.point22, height: MeetPRSpacing.point22)
        .background(
          LinearGradient(
            colors: [.MeetPR.textGhost, .MeetPR.surfaceKey],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          in: .circle
        )
        .overlay {
          Circle().stroke(Color.MeetPR.goldRGB.opacity(0.4), lineWidth: 1)
        }
      Text(text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct CompletionHeroStat: View {
  let value: String
  let suffix: String?
  let label: String

  var body: some View {
    VStack(spacing: MeetPRSpacing.point6) {
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        Text(value)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
          .monospacedDigit()
          .foregroundStyle(Color.MeetPR.goldText)
        if let suffix {
          Text(suffix)
            .font(.MeetPR.display(size: MeetPRFontMetrics.size15))
            .monospacedDigit()
            .foregroundStyle(Color.MeetPR.goldMuted)
        }
      }
      Text(label)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct CompletionSetTicker: View {
  let presentation: WorkoutCompletionPresentation

  var body: some View {
    VStack(spacing: MeetPRSpacing.point6) {
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        CompletionTicker(finalValue: presentation.completedSuccessfulSets)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
          .monospacedDigit()
          .foregroundStyle(Color.MeetPR.goldText)
        Text("/\(presentation.totalPlannedSets) 组")
          .font(.MeetPR.display(size: MeetPRFontMetrics.size15))
          .monospacedDigit()
          .foregroundStyle(Color.MeetPR.goldMuted)
      }
      Text(presentation.setCompletionLabel)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct CompletionTicker: View {
  let finalValue: Int

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var startedAt: Date?

  var body: some View {
    TimelineView(
      .animation(minimumInterval: 1 / 60, paused: startedAt == nil || reduceMotion)
    ) { context in
      let progress = min(
        1,
        max(0, context.date.timeIntervalSince(startedAt ?? context.date) / 0.9)
      )
      let displayed =
        reduceMotion
        ? finalValue
        : Int((Double(finalValue) * MeetPRMotion.easeOutQuart(progress)).rounded())
      Text(displayed.formatted(.number.grouping(.automatic)))
    }
    .task {
      guard !reduceMotion else { return }
      try? await Task.sleep(for: .milliseconds(470))
      guard !Task.isCancelled else { return }
      startedAt = Date()
    }
    .accessibilityLabel("\(finalValue) 组成功完成")
  }
}

private struct StreakCapsule: View {
  let streak: Int

  var body: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      Image(systemName: "flame.fill")
        .font(.system(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.gold500)
      Text("连续第 \(streak) 次训练")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .bold))
        .foregroundStyle(Color.MeetPR.goldText)
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.point6)
    .background(Color.MeetPR.goldRGB.opacity(0.10), in: .capsule)
    .overlay {
      Capsule().stroke(Color.MeetPR.goldRGB.opacity(0.3), lineWidth: 1)
    }
  }
}

private struct CompletionSlide: ViewModifier {
  let delay: TimeInterval

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visible = false

  func body(content: Content) -> some View {
    content
      .opacity(visible || reduceMotion ? 1 : 0)
      .offset(y: visible || reduceMotion ? 0 : 26)
      .task {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        withAnimation(
          .timingCurve(
            MeetPRMotion.easeOutX1,
            MeetPRMotion.easeOutY1,
            MeetPRMotion.easeOutX2,
            MeetPRMotion.easeOutY2,
            duration: 0.46
          )
        ) {
          visible = true
        }
      }
  }
}

private struct CompletionFade: ViewModifier {
  let delay: TimeInterval

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visible = false

  func body(content: Content) -> some View {
    content
      .opacity(visible || reduceMotion ? 1 : 0)
      .task {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        withAnimation(.linear(duration: 0.45)) {
          visible = true
        }
      }
  }
}
