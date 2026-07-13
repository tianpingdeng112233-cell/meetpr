import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct RestTimerExplanationView: View {
  let onAcknowledge: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      Image(systemName: "timer")
        .font(.largeTitle)
        .foregroundStyle(Color.MeetPR.brandRed)

      Text("休息时间会自动匹配")
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.fgPrimary)

      explanationRow(
        icon: "gauge.with.dots.needle.33percent",
        text: "按你记录的 RPE 自动匹配：RPE 低于 7 为 2 分钟，7 至 9 以下为 3 分钟，9 及以上为 4 分钟。"
      )
      explanationRow(icon: "person.fill.checkmark", text: "教练指定过休息时长的组，会按教练设定。")
      explanationRow(icon: "gearshape", text: "可在「我的 → 组间休息」修改默认行为。")

      Button("知道了", action: onAcknowledge)
        .buttonStyle(.borderedProminent)
        .tint(Color.MeetPR.brandRed)
        .frame(maxWidth: .infinity)
        .padding(.top, MeetPRSpacing.xs)
    }
    .padding(MeetPRSpacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.bg)
  }

  private func explanationRow(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.sm) {
      Image(systemName: icon)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .frame(width: 24)
      Text(text)
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
