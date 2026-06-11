import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachMyProfileView: View {
  @Bindable private var viewModel: CoachMyProfileViewModel

  init(viewModel: CoachMyProfileViewModel) {
    self.viewModel = viewModel
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
          Card(accessibilityLabel: "内测须知") {
            VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
              Eyebrow("V0.1 内测须知")
              Text("教练端当前开放排计划、看学员执行和写反馈。")
                .font(Font.MeetPR.body)
                .foregroundStyle(Color.MeetPR.fgPrimary)
            }
          }

          Card(accessibilityLabel: "版本") {
            HStack {
              Label("App 版本", systemImage: "info.circle")
                .font(Font.MeetPR.body)
                .foregroundStyle(Color.MeetPR.fgPrimary)
              Spacer()
              Text(viewModel.appVersion)
                .font(Font.MeetPR.bodyEmphasis)
                .foregroundStyle(Color.MeetPR.fgSecondary)
            }
          }

          Button {
            Task { @MainActor in
              await viewModel.logout()
            }
          } label: {
            Label(
              viewModel.isLoggingOut ? "退出中" : "退出登录",
              systemImage: "rectangle.portrait.and.arrow.right"
            )
            .font(Font.MeetPR.bodyEmphasis)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
          }
          .foregroundStyle(Color.MeetPR.brandRed)
          .background(Color.MeetPR.brandRedSoft)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
          .disabled(viewModel.isLoggingOut)
        }
        .padding(MeetPRSpacing.base)
      }
      .navigationTitle("我的")
      .background(Color.MeetPR.bg)
    }
  }
}
