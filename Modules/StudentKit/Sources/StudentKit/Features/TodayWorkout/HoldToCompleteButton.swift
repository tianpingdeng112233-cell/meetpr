import DesignSystem
import SwiftUI

/// The mockup's deliberate completion gate: pressing starts an 1,100ms fill;
/// releasing or leaving the control before it fills cancels and springs back.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct HoldToCompleteButton: View {
  let title: String
  let onComplete: @MainActor () -> Void

  @State private var progress = 0.0
  @State private var isHolding = false
  @State private var didComplete = false
  @State private var completionTrigger = false
  @State private var holdTask: Task<Void, Never>?

  var body: some View {
    ZStack(alignment: .leading) {
      Capsule()
        .fill(Color.MeetPR.holdTrack)
        .overlay {
          Capsule()
            .stroke(Color.MeetPR.gold500.opacity(0.5), lineWidth: 1)
        }
        .shadow(
          color: Color.MeetPR.gold500.opacity(0.15),
          radius: MeetPRSpacing.point10,
          y: MeetPRSpacing.space1
        )

      GeometryReader { proxy in
        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.gold400],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: proxy.size.width * progress)
          .shadow(
            color: Color.MeetPR.gold500.opacity(0.55),
            radius: MeetPRSpacing.point11
          )
      }

      Label(title, systemImage: "clock")
        .font(
          .MeetPR.system(
            size: MeetPRFontMetrics.size16,
            weight: .bold
          )
        )
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
    .frame(height: MeetPRSpacing.completionControlHeight)
    .scaleEffect(isHolding ? 0.96 : 1)
    .contentShape(.capsule)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          beginHolding()
        }
        .onEnded { _ in
          cancelHoldingIfNeeded()
        }
    )
    .sensoryFeedback(.impact(weight: .heavy), trigger: completionTrigger)
    .accessibilityElement()
    .accessibilityLabel(title)
    .accessibilityHint("按住一秒直到进度填满")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction {
      onComplete()
    }
    .onDisappear {
      holdTask?.cancel()
    }
  }

  private func beginHolding() {
    guard !isHolding, !didComplete else { return }
    isHolding = true
    withAnimation(.linear(duration: MeetPRMotion.durationHoldComplete)) {
      progress = 1
    }
    holdTask?.cancel()
    holdTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(MeetPRMotion.durationHoldComplete))
      guard !Task.isCancelled, isHolding else { return }
      isHolding = false
      didComplete = true
      completionTrigger.toggle()
      onComplete()
      try? await Task.sleep(for: .milliseconds(600))
      guard !Task.isCancelled else { return }
      progress = 0
      didComplete = false
    }
  }

  private func cancelHoldingIfNeeded() {
    guard !didComplete else { return }
    isHolding = false
    holdTask?.cancel()
    withAnimation(
      .timingCurve(
        0.4,
        0,
        0.2,
        1,
        duration: MeetPRMotion.durationHoldCancel
      )
    ) {
      progress = 0
    }
  }
}
