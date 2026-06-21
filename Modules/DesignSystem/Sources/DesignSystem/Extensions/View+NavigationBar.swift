import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
extension View {
  /// Hides the navigation bar on iOS. No-op on macOS, where the
  /// `.navigationBar` toolbar placement is unavailable — so the SPM packages
  /// still compile under `swift test` on the macOS CI runner.
  public func hideNavigationBar() -> some View {
    #if os(iOS)
      toolbar(.hidden, for: .navigationBar)
    #else
      self
    #endif
  }
}
