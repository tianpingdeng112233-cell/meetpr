import SwiftUI

/// The student-facing appearance preference.
///
/// Only the student experience ships both themes; the coach side and the
/// pre-auth flow stay dark, so this is applied at the student branch of the
/// root router rather than on the window.
public enum MeetPRAppearance: String, CaseIterable, Identifiable, Sendable {
  case system
  case light
  case dark

  public static let storageKey = "meetpr.appearance"

  /// ⚖️ David 2026-07-28: the student app opens in light mode by default;
  /// system-following and dark stay available in 我的 → 外观.
  public static let defaultPreference: MeetPRAppearance = .light

  public var id: String { rawValue }

  /// `nil` hands the decision back to the system, which is what
  /// `preferredColorScheme` expects for "follow device".
  public var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }

  public var label: String {
    switch self {
    case .system: DesignSystemStrings.appearanceSystem
    case .light: DesignSystemStrings.appearanceLight
    case .dark: DesignSystemStrings.appearanceDark
    }
  }

  public var symbolName: String {
    switch self {
    case .system: "circle.lefthalf.filled"
    case .light: "sun.max"
    case .dark: "moon"
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension View {
  /// Applies the stored student appearance preference to this subtree.
  public func meetPRStudentAppearance() -> some View {
    modifier(MeetPRStudentAppearanceModifier())
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MeetPRStudentAppearanceModifier: ViewModifier {
  @AppStorage(MeetPRAppearance.storageKey) private var stored = MeetPRAppearance.defaultPreference

  func body(content: Content) -> some View {
    content.preferredColorScheme(stored.colorScheme)
  }
}
