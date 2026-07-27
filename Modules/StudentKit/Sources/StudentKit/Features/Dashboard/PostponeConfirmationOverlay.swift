import DesignSystem
import Foundation
import SwiftUI

extension PlanShiftProposal: Identifiable {
  var id: UUID { planID }
}

@available(iOS 17.0, macOS 14.0, *)
struct PostponeConfirmationOverlay: View {
  let tomorrow: Date
  let isConfirming: Bool
  let onCancel: () -> Void
  let onConfirm: () -> Void

  var body: some View {
    ZStack {
      Button(action: onCancel) {
        Color.black.opacity(0.60)
          .ignoresSafeArea()
      }
      .buttonStyle(.plain)
      .accessibilityLabel("取消顺延")

      VStack(alignment: .leading, spacing: 0) {
        Text("今天有事？")
          .font(.MeetPR.display(size: MeetPRFontMetrics.size21))
          .foregroundStyle(Color.MeetPR.textPrimary)

        (Text("本次训练将顺延到 ")
          .foregroundStyle(Color.MeetPR.textTertiary)
          + Text("明天（\(Self.dateText(tomorrow))）")
          .foregroundStyle(Color.MeetPR.textPrimary)
          .bold()
          + Text("，之后的计划整体后移一天。教练会收到通知。")
          .foregroundStyle(Color.MeetPR.textTertiary))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .lineSpacing(MeetPRSpacing.point6)
          .padding(.top, MeetPRSpacing.point10)

        HStack(spacing: MeetPRSpacing.point10) {
          Button("取消", action: onCancel)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay {
              Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
            }
            .buttonStyle(PressScaleButtonStyle())

          Button(action: onConfirm) {
            Group {
              if isConfirming {
                ProgressView()
                  .tint(.black)
              } else {
                Text("顺延一天")
              }
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.white, in: .capsule)
          }
          .buttonStyle(PressScaleButtonStyle())
          .disabled(isConfirming)
        }
        .padding(.top, MeetPRSpacing.space5)
      }
      .padding(MeetPRSpacing.point22)
      .background(Color.MeetPR.surfaceElevated)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.modal)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.modal))
      .shadow(color: Color.black.opacity(0.50), radius: 30, y: 30)
      .padding(.horizontal, MeetPRSpacing.point28)
    }
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }

  static func dateText(
    _ date: Date,
    calendar: Calendar = PlanCalendarDayIdentity.utcCalendar
  ) -> String {
    let components = calendar.dateComponents([.month, .day, .weekday], from: date)
    let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    let weekdayIndex = max(0, min(weekdays.count - 1, (components.weekday ?? 1) - 1))
    return "\(components.month ?? 0)/\(components.day ?? 0) \(weekdays[weekdayIndex])"
  }
}
