import CoreModels
import DesignSystem
import SwiftUI

/// Top ribbon celebrating an e1RM breakthrough (spec 028 §5). Slides in from
/// the top, auto-dismisses after 3s, tap dismisses immediately; both paths
/// acknowledge the event so it stops re-surfacing on launch.
@available(iOS 17.0, macOS 14.0, *)
struct PRBanner: View {
  let event: PRBreakthroughEvent
  let exerciseName: String?
  let onDismiss: () -> Void

  @State private var autoDismissTask: Task<Void, Never>?

  var body: some View {
    Button {
      autoDismissTask?.cancel()
      onDismiss()
    } label: {
      HStack(spacing: MeetPRSpacing.sm) {
        Image(systemName: "crown.fill")
          .font(
            .MeetPR.system(
              size: MeetPRFontMetrics.size20
            )
          )
          .foregroundStyle(Color.MeetPR.gold500)
        VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
          Text(headline)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.gold500)
          Text(detail)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.textSecondary)
        }
        Spacer(minLength: 0)
        Image(systemName: "xmark")
          .font(
            .MeetPR.system(
              size: MeetPRFontMetrics.size13,
              weight: .bold
            )
          )
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      .padding(.horizontal, MeetPRSpacing.md)
      .padding(.vertical, MeetPRSpacing.sm)
      .background(Color.MeetPR.goldSoft)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.gold500.opacity(0.35), lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(PressScaleButtonStyle())
    .padding(.horizontal, MeetPRSpacing.md)
    .onAppear {
      autoDismissTask = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        onDismiss()
      }
    }
    .onDisappear { autoDismissTask?.cancel() }
    .transition(.move(edge: .top).combined(with: .opacity))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(headline)，\(detail)")
  }

  private var headline: String {
    if let exerciseName {
      "今天你的\(exerciseName) e1RM 突破！"
    } else {
      "今天你的 e1RM 突破！"
    }
  }

  private var detail: String {
    let new = StudentFormatting.kilograms(event.breakthroughE1RMKg)
    if event.previousMaxE1RMKg > 0 {
      return "\(new) kg（此前 \(StudentFormatting.kilograms(event.previousMaxE1RMKg)) kg）"
    }
    return "\(new) kg，第一个纪录点"
  }
}
