import SwiftUI

@MainActor
public struct SetReadOnlyCell: View {
  private let setNumber: Int
  private let weightText: String
  private let repsText: String
  private let rpeText: String
  private let isCompleted: Bool

  public init(
    setNumber: Int,
    weightKg: Decimal?,
    reps: Int?,
    rpe: Decimal?,
    isCompleted: Bool
  ) {
    self.setNumber = setNumber
    weightText = weightKg.map { "\(Self.decimalString($0)) kg" } ?? "-"
    repsText = reps.map(String.init) ?? "-"
    rpeText = rpe.map(Self.decimalString) ?? "-"
    self.isCompleted = isCompleted
  }

  public var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Text("#\(setNumber + 1)")
        .font(Font.MeetPR.monoLabel)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .frame(width: 42, alignment: .leading)

      metric(title: "Wt", value: weightText)
      metric(title: "Reps", value: repsText)
      metric(title: "RPE", value: rpeText)

      Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(isCompleted ? Color.MeetPR.green : Color.MeetPR.fgTertiary)
        .frame(width: 24)
    }
    .padding(.horizontal, MeetPRSpacing.sm)
    .padding(.vertical, 10)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .accessibilityElement(children: .combine)
  }

  private func metric(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title.uppercased())
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
      Text(value)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private static func decimalString(_ value: Decimal) -> String {
    let number = NSDecimalNumber(decimal: value)
    let raw = number.stringValue
    guard raw.contains(".") else { return raw }
    return raw.replacingOccurrences(
      of: #"0+$"#,
      with: "",
      options: .regularExpression
    )
    .replacingOccurrences(
      of: #"\.$"#,
      with: "",
      options: .regularExpression
    )
  }
}

#Preview {
  VStack(spacing: MeetPRSpacing.sm) {
    SetReadOnlyCell(setNumber: 0, weightKg: 142.5, reps: 5, rpe: 8, isCompleted: true)
    SetReadOnlyCell(setNumber: 1, weightKg: nil, reps: nil, rpe: nil, isCompleted: false)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}
