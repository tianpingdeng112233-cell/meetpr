import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct AuthFlowView: View {
  public init() {}

  public var body: some View {
    NavigationStack {
      LoginView()
    }
  }
}
