import SwiftUI

/// How a surface separates itself from the page behind it.
///
/// The two themes use opposite strategies, so this is not a colour swap:
/// dark stacks flat surfaces and draws a hairline border, light floats white
/// cards on a grey page with a diffuse shadow and *no* border. Applying both
/// treatments at once reads as dirty in light and muddy in dark, so every
/// card-like surface goes through this modifier instead of hard-coding either.
@available(iOS 17.0, macOS 14.0, *)
public struct MeetPRCardSurface: ViewModifier {
  public enum Elevation {
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

  private var borderColor: Color {
    switch elevation {
    case .card, .modal: Color.MeetPR.borderSubtle
    case .inset: Color.MeetPR.borderControl
    }
  }

  /// `0 4px 18px rgba(17,24,39,.06)` from the light mockups, deepened a step
  /// for modals. Dark theme draws no shadow at all.
  private struct Shadow {
    let color: Color
    let radius: CGFloat
    let offsetY: CGFloat
  }

  private var shadow: Shadow {
    switch elevation {
    case .card, .inset: Shadow(color: Color.MeetPR.cardShadow, radius: 9, offsetY: 4)
    case .modal: Shadow(color: Color.MeetPR.modalShadow, radius: 30, offsetY: 20)
    }
  }

  public func body(content: Content) -> some View {
    let isLight = colorScheme == .light
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return
      content
      .background(backgroundColor)
      .clipShape(shape)
      .overlay {
        if !isLight {
          shape.stroke(borderColor, lineWidth: 1)
        }
      }
      .shadow(
        color: isLight ? shadow.color : .clear,
        radius: isLight ? shadow.radius : 0,
        y: isLight ? shadow.offsetY : 0
      )
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension View {
  /// Applies the theme's surface-separation strategy: hairline border on dark,
  /// diffuse shadow on light. See ``MeetPRCardSurface``.
  public func meetPRCardSurface(
    _ elevation: MeetPRCardSurface.Elevation = .card,
    fill: Color? = nil
  ) -> some View {
    modifier(MeetPRCardSurface(elevation: elevation, fill: fill))
  }
}
