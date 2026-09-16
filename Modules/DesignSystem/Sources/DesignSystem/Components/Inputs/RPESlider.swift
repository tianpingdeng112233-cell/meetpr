import SwiftUI

@MainActor
public struct RPESlider: View {
  @Binding private var value: Double

  public init(value: Binding<Double>) {
    self._value = value
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      HStack(alignment: .firstTextBaseline) {
        Text("RPE")
          .font(.MeetPR.mono(size: 11, weight: .bold))
          .tracking(0.8)
          .foregroundStyle(Color.MeetPR.textMuted)

        Spacer()

        Text(formattedValue)
          .font(.MeetPR.display(size: 34, weight: .black))
          .foregroundStyle(Color.MeetPR.gold500)
          .monospacedDigit()

        Text("/ 10")
          .font(.MeetPR.mono(size: 11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }

      GeometryReader { proxy in
        let width = proxy.size.width
        VStack(spacing: MeetPRSpacing.sm) {
          HStack(alignment: .bottom, spacing: MeetPRSpacing.xs) {
            ForEach(0..<11, id: \.self) { index in
              RPEBar(index: index, selectedIndex: selectedIndex)
            }
          }
          .frame(height: 44, alignment: .bottom)
          .contentShape(.rect)
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { gesture in
                updateValue(x: gesture.location.x, width: width)
              }
          )

          HStack {
            Text("5")
            Spacer()
            Text("7.5")
            Spacer()
            Text("10")
          }
          .font(.MeetPR.mono(size: 10, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
        }
      }
      .frame(height: 68)
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
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

  private var selectedIndex: Int {
    Int((progress * 10).rounded())
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

@MainActor
private struct RPEBar: View {
  let index: Int
  let selectedIndex: Int

  var body: some View {
    Capsule()
      .fill(index <= selectedIndex ? Color.MeetPR.gold500 : Color.MeetPR.borderDefault)
      .frame(maxWidth: .infinity)
      .frame(height: 18 + CGFloat(index) * 2.4)
      .shadow(
        color: index == selectedIndex ? Color.MeetPR.gold500.opacity(0.5) : .clear,
        radius: 8
      )
  }
}

#Preview("RPESlider") {
  @Previewable @State var rpe = 8.5

  RPESlider(value: $rpe)
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.dark)
}

#Preview("RPESlider Light") {
  @Previewable @State var rpe = 6.0

  RPESlider(value: $rpe)
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
