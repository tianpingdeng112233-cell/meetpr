import Analytics
import Foundation
import Networking
import StudentKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AnalyticsRootModifier: ViewModifier {
  let session: Session
  let mode: AnalyticsMode

  @Environment(\.scenePhase) private var scenePhase
  @State private var didConfigure = false
  @State private var showingNotice: Bool
  @State private var noticeDismissed: Bool

  init(session: Session, mode: AnalyticsMode) {
    self.session = session
    self.mode = mode
    _showingNotice = State(initialValue: Self.shouldShowNotice(mode: mode))
    _noticeDismissed = State(initialValue: !Self.shouldShowNotice(mode: mode))
  }

  func body(content: Content) -> some View {
    content
      .environment(
        \.isStudentPresentationBlocked,
        showingNotice || !noticeDismissed || FrictionFeedbackController.shared.pendingPrompt != nil
      )
      .sheet(isPresented: $showingNotice, onDismiss: noticeDidDismiss) {
        AnalyticsPrivacyNotice {
          Analytics.shared.confirmPrivacyNotice()
          showingNotice = false
        }
        .interactiveDismissDisabled()
      }
      .task {
        guard !didConfigure else { return }
        didConfigure = true
        Analytics.shared.configure(
          baseURL: BuildConfig.backendBaseURL,
          transport: { request, body in
            try await URLSession.shared.upload(for: request, from: body)
          },
          accessTokenProvider: { await session.analyticsAccessToken() },
          mode: mode,
          privacyNoticeConfirmed: !showingNotice
        )
        Analytics.shared.track(.appOpen, props: ["cold": .bool(true)])
      }
      .onChange(of: scenePhase) { _, phase in
        switch phase {
        case .background:
          Analytics.shared.didEnterBackground()
        case .active:
          Analytics.shared.willEnterForeground()
        case .inactive:
          break
        @unknown default:
          break
        }
      }
  }

  private func noticeDidDismiss() { noticeDismissed = true }

  static func shouldShowNotice(mode: AnalyticsMode, defaults: UserDefaults = .standard) -> Bool {
    guard case .live = mode else { return false }
    return defaults.string(forKey: LegalDocuments.acceptedVersionKey)
      != LegalDocuments.version
  }
}
