import SwiftUI

/// Draws one `LaunchSplashFrame`. Geometry is the design's 1080-wide canvas,
/// scaled to the screen width and anchored on the screen centre; the background
/// fills the whole screen instead of the reference's 9:16 stage.
@available(iOS 17.0, macOS 14.0, *)
struct LaunchSplashView: View {
  let frame: LaunchSplashFrame

  private enum Canvas {
    static let width = 1080.0
    static let minHeight = 1400.0
    static let logoWidth = 832.0
    static let logoAspect = 2443.0 / 605.0
    static let logoCenterY = -78.2
    static let taglineCenterY = 99.05
    static let taglineSize = 44.0
    static let loaderCenterY = 161.25
    static let trackWidth = 196.0
    static let pillWidth = 57.0
    static let barHeight = 6.0
    static let barSquash = 2.0 / 3
    static let pillGlow = 16.0
    static let glowCenterY = -76.8
    static let glowRadiusX = 604.8
    static let glowRadiusY = 652.8
  }

  private static let ink = Color(red: 16 / 255, green: 23 / 255, blue: 38 / 255)
  private static let ember = Color(red: 230 / 255, green: 104 / 255, blue: 30 / 255)
  private static let warm = Color(red: 232 / 255, green: 150 / 255, blue: 86 / 255)
  private static let warmClear = Color(red: 247 / 255, green: 241 / 255, blue: 233 / 255)
  private static let paper = Color(red: 245 / 255, green: 246 / 255, blue: 248 / 255)

  var body: some View {
    GeometryReader { proxy in
      let unit = min(proxy.size.width / Canvas.width, proxy.size.height / Canvas.minHeight)
      ZStack {
        wordmark(unit: unit)
        tagline(unit: unit)
        loader(unit: unit)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      // Backgrounds, so the glow (wider than the screen) and the filled
      // image cannot stretch the layout the foreground is centred in.
      .background { glow(unit: unit) }
      .background { background(size: proxy.size) }
    }
    .background(Self.paper)
    .ignoresSafeArea()
    // The splash is light-only by design, in dark appearance too.
    .environment(\.colorScheme, .light)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("MeetPR")
  }

  private func background(size: CGSize) -> some View {
    ZStack {
      Image("LaunchSplashBackground", bundle: .module)
        .resizable()
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .clipped()
      LinearGradient(
        stops: [
          .init(color: Self.warm.opacity(frame.warmTopAlpha), location: 0),
          .init(color: Self.warmClear.opacity(0), location: 0.46),
          .init(color: Color.white.opacity(frame.warmBottomAlpha), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .frame(width: size.width, height: size.height)
  }

  private func glow(unit: Double) -> some View {
    Ellipse()
      .fill(
        EllipticalGradient(
          stops: [
            .init(color: Self.ember.opacity(frame.glowAlpha), location: 0),
            .init(color: Self.ember.opacity(0), location: 0.7),
          ],
          center: .center,
          startRadiusFraction: 0,
          endRadiusFraction: 0.5
        )
      )
      .frame(width: 2 * Canvas.glowRadiusX * unit, height: 2 * Canvas.glowRadiusY * unit)
      .offset(y: Canvas.glowCenterY * unit)
      .scaleEffect(frame.glowScale)
  }

  private func wordmark(unit: Double) -> some View {
    Image("LaunchSplashWordmark", bundle: .module)
      .resizable()
      .frame(
        width: Canvas.logoWidth * unit,
        height: Canvas.logoWidth / Canvas.logoAspect * unit
      )
      .shadow(
        color: Self.ink.opacity(frame.logoShadowAlpha),
        radius: frame.logoShadowBlur * unit,
        y: frame.logoShadowY * unit
      )
      .scaleEffect(frame.logoScale)
      .opacity(frame.logoOpacity)
      .offset(y: (Canvas.logoCenterY + frame.logoOffsetY) * unit)
  }

  private func tagline(unit: Double) -> some View {
    // Brand line stays in English in every locale (spec 099).
    Text(verbatim: "Meet Every PR Together")
      .font(.system(size: Canvas.taglineSize * unit, weight: .bold))
      .kerning(frame.taglineTrackingEm * Canvas.taglineSize * unit)
      .foregroundStyle(Self.ink)
      .lineLimit(1)
      .fixedSize()
      .opacity(frame.taglineOpacity)
      .offset(y: (Canvas.taglineCenterY + frame.taglineOffsetY) * unit)
  }

  private func loader(unit: Double) -> some View {
    let travel = (Canvas.trackWidth - Canvas.pillWidth) * unit
    return ZStack(alignment: .leading) {
      Capsule()
        .fill(Self.ink.opacity(frame.trackAlpha))
      Capsule()
        .fill(Self.ember)
        .frame(width: Canvas.pillWidth * unit)
        .shadow(color: Self.ember.opacity(0.55), radius: Canvas.pillGlow * unit / 2)
        .opacity(frame.pillOpacity)
        .offset(x: travel * frame.pillProgress)
    }
    .frame(width: Canvas.trackWidth * unit, height: Canvas.barHeight * unit)
    // The reference renders this layer vertically squashed to two thirds.
    .scaleEffect(x: 1, y: Canvas.barSquash)
    .offset(y: Canvas.loaderCenterY * unit)
  }
}
