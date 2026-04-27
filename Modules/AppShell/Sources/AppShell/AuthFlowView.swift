import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct AuthFlowView: View {
  @Environment(Session.self) private var session

  public init() {}

  public var body: some View {
    VStack {
      PrimaryButton("Sign in as Coach") {
        session.fakeLogin(role: .coach)
      }

      Button("Sign in as Student") {
        session.fakeLogin(role: .coachedStudent)
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }
}
