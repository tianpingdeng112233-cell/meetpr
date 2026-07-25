import DesignSystem
import SwiftUI
import Testing
import UIKit

/// Locks the invariants that make the student side legible in both themes.
///
/// Every value here was read off the paired light/dark mockups, so a failure
/// means the token drifted away from the design, not that the test is stale.
///
/// These live in the app test target rather than `DesignSystemTests` on
/// purpose: resolving a dynamic `Color` needs a `UITraitCollection`, and the
/// SwiftPM test bundles run on the macOS host where an `#if os(iOS)` body
/// would compile away and pass without ever executing.
@Suite("Dual theme")
@MainActor
struct DualThemeTests {
  /// A colour resolved against one theme, in 0...1 sRGB components.
  private struct Resolved: Equatable {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    /// Sum of absolute channel differences — a cheap "are these visibly
    /// different" measure that avoids importing a colour-science model.
    func distance(to other: Resolved) -> CGFloat {
      abs(red - other.red) + abs(green - other.green) + abs(blue - other.blue)
    }
  }

  private func rgba(_ color: Color, _ scheme: ColorScheme) -> Resolved {
    let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
    var resolved = Resolved()
    UIColor(color)
      .resolvedColor(with: traits)
      .getRed(&resolved.red, green: &resolved.green, blue: &resolved.blue, alpha: &resolved.alpha)
    return resolved
  }

  private func isDistinct(_ color: Color) -> Bool {
    rgba(color, .light).distance(to: rgba(color, .dark)) > 0.01
  }

  @Test("Surfaces, text and borders all resolve differently per theme")
  func coreTokensAreThemeAware() {
    let mustDiffer: [(String, Color)] = [
      ("bgBase", Color.MeetPR.bgBase),
      ("surfaceCard", Color.MeetPR.surfaceCard),
      ("surfaceRaised", Color.MeetPR.surfaceRaised),
      ("borderSubtle", Color.MeetPR.borderSubtle),
      ("borderControl", Color.MeetPR.borderControl),
      ("textPrimary", Color.MeetPR.textPrimary),
      ("textSecondary", Color.MeetPR.textSecondary),
      ("microLabel", Color.MeetPR.microLabel),
      ("pendingRing", Color.MeetPR.pendingRing),
      ("bodyStrong", Color.MeetPR.bodyStrong),
      ("displayText", Color.MeetPR.displayText),
      ("coachNoteText", Color.MeetPR.coachNoteText),
      ("gold500", Color.MeetPR.gold500),
      ("success", Color.MeetPR.success),
      ("ctaBackground", Color.MeetPR.ctaBackground),
      ("ctaText", Color.MeetPR.ctaText),
      ("ctaTextSecondary", Color.MeetPR.ctaTextSecondary),
      ("ctaGlow", Color.MeetPR.ctaGlow),
    ]
    for (name, color) in mustDiffer {
      #expect(isDistinct(color), "\(name) resolves to the same colour in both themes")
    }
  }

  @Test("The CTA subtitle stays legible against each theme's CTA fill")
  func ctaSubtitleContrastsWithItsFill() {
    for scheme in [ColorScheme.light, .dark] {
      let fill = rgba(Color.MeetPR.ctaBackground, scheme)
      let subtitle = rgba(Color.MeetPR.ctaTextSecondary, scheme)
      #expect(
        fill.distance(to: subtitle) > 0.5,
        "CTA subtitle is too close to the CTA fill in \(scheme)"
      )
    }
  }

  @Test("Light CTA is navy with amber subtitle, dark CTA is gold with dark ink")
  func ctaMatchesTheMockups() {
    let lightFill = rgba(Color.MeetPR.ctaBackground, .light)
    #expect(abs(lightFill.red - 17 / 255) < 0.01)
    #expect(abs(lightFill.green - 24 / 255) < 0.01)
    #expect(abs(lightFill.blue - 39 / 255) < 0.01)

    let lightSubtitle = rgba(Color.MeetPR.ctaTextSecondary, .light)
    #expect(abs(lightSubtitle.red - 245 / 255) < 0.01)
    #expect(abs(lightSubtitle.green - 158 / 255) < 0.01)
    #expect(abs(lightSubtitle.blue - 11 / 255) < 0.01)

    let darkFill = rgba(Color.MeetPR.ctaBackground, .dark)
    #expect(abs(darkFill.red - 255 / 255) < 0.01)
    #expect(abs(darkFill.green - 184 / 255) < 0.01)
    #expect(abs(darkFill.blue - 0) < 0.01)
  }

  @Test("A count badge is not the same red as a failed set")
  func countBadgeIsDistinctFromDanger() {
    let badge = rgba(MeetPRSemanticTone.unreadBadge.color, .dark)
    let danger = rgba(MeetPRSemanticTone.danger.color, .dark)
    #expect(badge != danger)
    #expect(abs(badge.red - 255 / 255) < 0.01)
    #expect(abs(badge.green - 59 / 255) < 0.01)
    #expect(abs(badge.blue - 48 / 255) < 0.01)
  }

  @Test("An inline new-item dot is gold, matching both mockups")
  func inlineDotIsGold() {
    for scheme in [ColorScheme.light, .dark] {
      let dot = rgba(MeetPRSemanticTone.inProgress.color, scheme)
      let gold = rgba(Color.MeetPR.gold500, scheme)
      #expect(dot == gold)
    }
  }

  @Test("Appearance options map onto the scheme SwiftUI expects")
  func appearanceMapsToColorScheme() {
    #expect(MeetPRAppearance.system.colorScheme == nil)
    #expect(MeetPRAppearance.light.colorScheme == .light)
    #expect(MeetPRAppearance.dark.colorScheme == .dark)
    #expect(MeetPRAppearance.allCases.count == 3)
  }
}
