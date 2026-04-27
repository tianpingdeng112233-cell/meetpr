import CoachKit
import CoreModels
import StudentKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct RootView: View {
  @Environment(Session.self) private var session

  public init() {}

  public var body: some View {
    switch session.state {
    case .anonymous, .authenticating:
      AuthFlowView()
    case .authenticated(let user):
      switch user.role {
      case .coach:
        CoachRootView()
      case .student:
        StudentRootView()
      }
    }
  }
}
