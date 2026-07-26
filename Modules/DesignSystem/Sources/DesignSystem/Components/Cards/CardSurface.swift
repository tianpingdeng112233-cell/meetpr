import SwiftUI

/// How a surface separates itself from the page behind it, per the mockup:
/// plain cards are flat in both themes (light adds the diffuse `--card-shadow`,
/// dark none); inset/stacked ghosts stroke `--surface-key` in both themes;
/// dialogs stroke `--border-default` and cast `0 30px 60px rgba(0,0,0,.5)` in
/// both themes. Card-like surfaces go through this modifier instead of
/// hard-coding any of those treatments.
@available(iOS 17.0, macOS 14.0, *)
public struct MeetPRCardSurface: ViewModifier {
  public enum Elevation: Sendable {
    /// Cards and containers sitting directly on the page.
    case card
    /// Panels nested inside another card — lighter separation on both themes.
    case inset
    /// Dialogs and bottom sheets.
    case modal
  }

  @Environment(\.colorScheme) private var colorScheme

  private let elevation: Elevation
  private let fill: Color?

  public init(elevation: Elevation = .card, fill: Color? = nil) {
    self.elevation = elevation
    self.fill = fill
  }

  private var cornerRadius: CGFloat {
    switch elevation {
    case .card: MeetPRRadius.card
    case .inset: MeetPRRadius.chip
    case .modal: MeetPRRadius.modal
    }
  }

  private var backgroundColor: Color {
    if let fill { return fill }
    switch elevation {
    case .card: return Color.MeetPR.surfaceCard
    case .inset: return Color.MeetPR.bgInset
    case .modal: return Color.MeetPR.surfaceElevated
    }
  }

  private var borderColor: Color? {
    switch elevation {
    // Plain cards are flat in the mockup: `var(--surface-card)`, no stroke.
    case .card: nil
    // Stacked/inset ghosts draw `1px solid var(--surface-key)`, both themes.
    case .inset: Color.MeetPR.surfaceKey
    // Dialogs draw `1px solid var(--border-default)`, both themes.
    case .modal: Color.MeetPR.borderDefault
    }
  }

  private struct Shadow {
    let color: Color
    let radius: CGFloat
    let offsetY: CGFloat
    let lightOnly: Bool
  }

  private var shadow: Shadow? {
    switch elevation {
    // `--card-shadow`: `0 4px 18px rgba(17,24,39,.06)` on light, none on dark.
    case .card:
      Shadow(color: Color.MeetPR.cardShadow, radius: 9, offsetY: 4, lightOnly: true)
    // Stacked/inset ghosts are background + border only — no shadow at all.
    case .inset:
      nil
    // `0 30px 60px rgba(0,0,0,.5)` — mockup literal, both themes.
    case .modal:
      Shadow(color: Color.MeetPR.modalShadow, radius: 30, offsetY: 30, lightOnly: false)
    }
  }

  public func body(content: Content) -> some View {
    let isLight = colorScheme == .light
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    let visibleShadow = shadow.flatMap { !$0.lightOnly || isLight ? $0 : nil }
    return
      content
      .background(backgroundColor)
      .clipShape(shape)
      .overlay {
        if let borderColor {
          shape.stroke(borderColor, lineWidth: 1)
        }
      }
      .shadow(
        color: visibleShadow?.color ?? .clear,
        radius: visibleShadow?.radius ?? 0,
        y: visibleShadow?.offsetY ?? 0
      )
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension View {
  /// Applies the mockup's surface-separation strategy per elevation: `.card`
  /// flat (light-only `--card-shadow`), `.inset` `surface-key` border only,
  /// `.modal` `border-default` plus the dialog shadow, each in both themes.
  /// See ``MeetPRCardSurface``.
  public func meetPRCardSurface(
    _ elevation: MeetPRCardSurface.Elevation = .card,
    fill: Color? = nil
  ) -> some View {
    modifier(MeetPRCardSurface(elevation: elevation, fill: fill))
  }
}
