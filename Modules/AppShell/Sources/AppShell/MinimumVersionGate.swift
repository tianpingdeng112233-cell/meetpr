import DesignSystem
import Networking
import SwiftUI

/// Owns the root presentation so an existing sheet cannot cover or dismiss the update gate.
@MainActor
public struct MinimumVersionGate<Content: View>: View {
  private let content: Content
  @State private var model = MinimumVersionGateModel()

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  init(model: MinimumVersionGateModel, @ViewBuilder content: () -> Content) {
    self.content = content()
    _model = State(initialValue: model)
  }

  public var body: some View {
    Group {
      if let minimumBuild = model.minimumBuild {
        RequiredAppUpdateView(minimumBuild: minimumBuild)
      } else {
        content
      }
    }
    .task {
      await model.check()
    }
  }
}

struct RequiredAppUpdateView: View {
  let minimumBuild: Int
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space6) {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space6) {
          Image("MeetPRUpdateIcon")
            .resizable()
            .frame(width: 72, height: 72)
            .clipShape(.rect(cornerRadius: 18))
            .accessibilityHidden(true)
          Text(copy("appShell.update.title"))
            .font(.largeTitle.bold())
            .fixedSize(horizontal: false, vertical: true)
          Text(copy("appShell.update.body"))
            .font(.body)
            .foregroundStyle(Color.MeetPR.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
          VStack(spacing: MeetPRSpacing.space4) {
            LabeledContent(copy("appShell.update.current"), value: currentVersion)
            LabeledContent(copy("appShell.update.minimum"), value: "build \(minimumBuild)")
          }
          .font(.body)
          .padding(MeetPRSpacing.space4)
          .background(.white, in: .rect(cornerRadius: MeetPRRadius.card))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
      Button {
        if let url = BuildConfig.updateURL() { openURL(url) }
      } label: {
        Text(copy("appShell.update.action"))
          .font(.headline)
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
          .padding(.vertical, MeetPRSpacing.space2)
          .foregroundStyle(.white)
          .background(.black, in: .rect(cornerRadius: MeetPRRadius.card))
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("app.update.action")
    }
    .padding(MeetPRSpacing.space6)
    .background(Color.MeetPR.bgBase.ignoresSafeArea())
    .preferredColorScheme(.light)
    .accessibilityIdentifier("app.update.required")
  }

  private var currentVersion: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return "\(version ?? "—") (build \(build ?? "—"))"
  }

  private func copy(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
