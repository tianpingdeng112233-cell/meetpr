import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AnalyticsPrivacyNotice: View {
  let onConfirm: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("使用数据说明")
        .font(.title2.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text(
        "为改进训练流程,MeetPR 会收集产品交互、匿名设备标识,以及你主动填写的反馈文本。"
          + "数据仅用于产品功能,留存在境内自建阿里云,不接入第三方统计 SDK、不出境,"
          + "也不用于追踪或广告。数据保留 90 天;卸载会清除匿名安装标识,"
          + "你可通过删除账号或联系我们请求删除。"
      )
      .font(.body)
      .foregroundStyle(Color.MeetPR.fgSecondary)
      Link("隐私政策", destination: Self.privacyPolicyURL)
      Button("知道了", action: onConfirm)
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(24)
    .background(Color.MeetPR.bg)
    .presentationDetents([.medium])
  }

  static let privacyPolicyURL =
    URL(string: "https://meetpr.app/privacy") ?? URL(fileURLWithPath: "/")
}
