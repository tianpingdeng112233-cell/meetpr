import SwiftUI

/// ⛔️ FROZEN W0 view — compatibility quarantine, not a v3 component.
///
/// New code must use `SetRow`. This implementation exists only so coach-side
/// screens keep the exact `2e46d52` rendering until the coach migration wave;
/// delete it after that migration.
@MainActor
struct LegacySetReadOnlyCell: View {
  let setNumber: Int
  let weightText: String
  let repsText: String
  let rpeText: String
  let isCompleted: Bool
  let isFailed: Bool
  let isVideoUploaded: Bool

  init(
    setNumber: Int,
    weightKg: Decimal?,
    reps: Int?,
    rpe: Decimal?,
    isCompleted: Bool,
    isFailed: Bool = false,
    isVideoUploaded: Bool = false
  ) {
    self.setNumber = setNumber
    weightText = weightKg.map { "\(Self.decimalString($0)) kg" } ?? "-"
    repsText = reps.map(String.init) ?? "-"
    rpeText = rpe.map(Self.decimalString) ?? "-"
    self.isCompleted = isCompleted
    self.isFailed = isFailed
    self.isVideoUploaded = isVideoUploaded
  }

  var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Text("#\(setNumber + 1)")
        .font(.MeetPR.mono(size: 11, weight: .bold))
        .foregroundStyle(isCompleted ? Color.MeetPR.success : Color.MeetPR.textMuted)
        .frame(width: 42, alignment: .leading)

      metric(title: "Wt", value: weightText)
      metric(title: "Reps", value: repsText)
      metric(title: "RPE", value: rpeText)

      HStack(spacing: MeetPRSpacing.xs) {
        if isVideoUploaded {
          Image(systemName: "video.fill")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size18, weight: .semibold))
            .foregroundStyle(Color.MeetPR.success)
        }

        Image(systemName: statusIconName)
          .font(
            .MeetPR.system(
              size: MeetPRFontMetrics.size18,
              weight: .semibold
            )
          )
          .foregroundStyle(statusColor)
      }
      .frame(width: 42, alignment: .trailing)
    }
    .padding(.horizontal, MeetPRSpacing.sm)
    .padding(.vertical, MeetPRSpacing.point10)
    .background(isCompleted ? Color.MeetPR.successTint : Color.MeetPR.bgInset)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .stroke(
          isCompleted ? Color.MeetPR.success.opacity(0.28) : Color.MeetPR.borderSubtle,
          lineWidth: 1
        )
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .accessibilityElement(children: .combine)
  }

  private var statusIconName: String {
    if isFailed {
      "xmark.circle.fill"
    } else if isCompleted {
      "checkmark.circle.fill"
    } else {
      "circle"
    }
  }

  private var statusColor: Color {
    if isFailed {
      Color.MeetPR.danger
    } else if isCompleted {
      Color.MeetPR.success
    } else {
      Color.MeetPR.textMuted
    }
  }

  private func metric(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
      Text(title.uppercased())
        .font(.MeetPR.mono(size: 10, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
      Text(value)
        .font(.MeetPR.mono(size: 14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
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

/// Frozen W0 public entry. New code must use `SetRow`.
@MainActor
public struct SetReadOnlyCell: View {
  private let legacy: LegacySetReadOnlyCell

  public init(
    setNumber: Int,
    weightKg: Decimal?,
    reps: Int?,
    rpe: Decimal?,
    isCompleted: Bool,
    isFailed: Bool = false,
    isVideoUploaded: Bool = false
  ) {
    legacy = LegacySetReadOnlyCell(
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      isCompleted: isCompleted,
      isFailed: isFailed,
      isVideoUploaded: isVideoUploaded
    )
  }

  public var body: some View {
    legacy
  }
}
