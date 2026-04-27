import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct PrimaryButton: View {
  private let title: LocalizedStringKey
  private let action: @MainActor () -> Void

  public init(_ title: LocalizedStringKey, action: @escaping @MainActor () -> Void) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Text(title)
        .bold()
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(.meetprPrimary)
  }
}
