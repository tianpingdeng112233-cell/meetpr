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
    HStack(spacing: MeetPRSpacing.sm) {
      Text("🎉")
        .font(.system(size: 24))
      VStack(alignment: .leading, spacing: 2) {
        Text(headline)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(.white)
        Text(detail)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(.white.opacity(0.85))
      }
      Spacer(minLength: 0)
      Image(systemName: "xmark")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white.opacity(0.7))
    }
    .padding(.horizontal, MeetPRSpacing.md)
    .padding(.vertical, MeetPRSpacing.sm)
    .background(Color.MeetPR.green)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    .padding(.horizontal, MeetPRSpacing.md)
    .onTapGesture {
      autoDismissTask?.cancel()
      onDismiss()
    }
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
    let new = Self.kg(event.breakthroughE1RMKg)
    if event.previousMaxE1RMKg > 0 {
      return "\(new) kg（此前 \(Self.kg(event.previousMaxE1RMKg)) kg）"
    }
    return "\(new) kg，第一个纪录点"
  }

  private static func kg(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
      ? String(Int(value))
      : String(format: "%.1f", value)
  }
}
