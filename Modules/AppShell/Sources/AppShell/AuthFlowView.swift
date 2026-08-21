import Networking
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct AuthFlowView: View {
  private let buildTrack: MeetPRBuildTrack

  public init(buildTrack: MeetPRBuildTrack = BuildConfig.buildTrack) {
    self.buildTrack = buildTrack
  }

  public var body: some View {
    NavigationStack {
      switch buildTrack {
      case .china:
        LoginView()
      case .global:
        GlobalLoginView()
      }
    }
  }
}
