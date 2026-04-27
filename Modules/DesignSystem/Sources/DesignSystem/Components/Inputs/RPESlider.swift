import SwiftUI

@MainActor
public struct RPESlider: View {
  @Binding private var value: Double

  public init(value: Binding<Double>) {
    self._value = value
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
      Text("RPE")
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.brandRed)

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
        Text(formattedValue)
          .font(Font.MeetPR.displayNumeral)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .monospacedDigit()

        Text("/ 10")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }

      GeometryReader { proxy in
        let width = proxy.size.width
        let fillWidth = width * progress
        let thumbX = max(12, min(width - 12, fillWidth))

        VStack(spacing: MeetPRSpacing.xs) {
          ZStack(alignment: .leading) {
            Capsule()
              .fill(Color.MeetPR.border)
              .frame(height: 4)

            Capsule()
              .fill(Color.MeetPR.fgPrimary)
              .frame(width: fillWidth, height: 4)

            Circle()
              .stroke(Color.MeetPR.fgPrimary.opacity(0.08), lineWidth: 8)
              .frame(width: 32, height: 32)
              .position(x: thumbX, y: 12)

            Circle()
              .fill(Color.MeetPR.fgPrimary)
              .frame(width: 24, height: 24)
              .position(x: thumbX, y: 12)
          }
          .frame(height: 24)
          .contentShape(.rect)
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { gesture in
                updateValue(x: gesture.location.x, width: width)
              }
          )

          HStack {
            ForEach(["5.0", "6.0", "7.0", "8.0", "9.0", "10.0"], id: \.self) { tick in
              Text(tick)
                .font(Font.MeetPR.caption)
                .monospacedDigit()
                .foregroundStyle(Color.MeetPR.fgTertiary)
              if tick != "10.0" {
                Spacer(minLength: 0)
              }
            }
          }
        }
      }
      .frame(height: 48)
    }
    .padding(20)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .sensoryFeedback(.selection, trigger: steppedValue)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("RPE")
    .accessibilityValue("\(formattedValue) out of 10")
    .accessibilityHint("Swipe up or down to adjust in half-point steps.")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment:
        value = min(10, steppedValue + 0.5)
      case .decrement:
        value = max(5, steppedValue - 0.5)
      @unknown default:
        break
      }
    }
  }

  private var steppedValue: Double {
    min(10, max(5, (value * 2).rounded() / 2))
  }

  private var progress: Double {
    (steppedValue - 5) / 5
  }

  private var formattedValue: String {
    steppedValue.formatted(.number.precision(.fractionLength(1)))
  }

  private func updateValue(x: CGFloat, width: CGFloat) {
    let normalized = min(1, max(0, x / max(width, 1)))
    let rawValue = 5 + (normalized * 5)
    value = (rawValue * 2).rounded() / 2
  }
}

#Preview("RPESlider") {
  @Previewable @State var rpe = 8.5

  RPESlider(value: $rpe)
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.dark)
}

#Preview("RPESlider Light") {
  @Previewable @State var rpe = 6.0

  RPESlider(value: $rpe)
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
