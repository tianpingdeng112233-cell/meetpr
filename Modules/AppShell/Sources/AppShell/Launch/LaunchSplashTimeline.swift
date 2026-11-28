import Foundation

/// One moment of the launch splash, in the design's 1080-wide canvas units.
/// Mirrors `render(t)` in specs/099-launch-animation/reference/splash.html.
struct LaunchSplashFrame: Equatable {
  var warmTopAlpha: Double
  var warmBottomAlpha: Double
  var glowAlpha: Double
  var glowScale: Double
  var logoOpacity: Double
  var logoOffsetY: Double
  var logoScale: Double
  var logoShadowY: Double
  var logoShadowBlur: Double
  var logoShadowAlpha: Double
  var taglineOpacity: Double
  var taglineOffsetY: Double
  var taglineTrackingEm: Double
  var trackAlpha: Double
  var pillOpacity: Double
  /// 0 = pill at the left end of the track, 1 = at the right end.
  var pillProgress: Double
}

enum LaunchSplashTimeline {
  static let entranceDuration = 1.2
  static let exitDuration = 0.3

  static let logoEnter = 19.0 / 30
  static let glowRamp = 0.7
  static let taglineStart = 7.0 / 30
  static let taglineEnd = 25.0 / 30
  static let loaderStart = 13.0 / 30
  static let loaderFade = 8.0 / 30

  // After the entrance the loader keeps sweeping left to right and never
  // travels back: fade out at the right end, then repeat this cycle.
  static let loopFadeOut = 0.2
  static let loopPeriod = 1.1
  static let loopFadeOutStart = 0.8

  static func frame(at time: Double) -> LaunchSplashFrame {
    let now = max(0, time)
    let glow = easeOutQuad(clamp01(now / glowRamp))
    let warm = clamp01(now / (entranceDuration * 35 / 36))
    let enter = easeLogo(clamp01(now / logoEnter))
    let tagline = easeOutCubic(clamp01((now - taglineStart) / (taglineEnd - taglineStart)))
    let loader = loader(at: now)
    return LaunchSplashFrame(
      warmTopAlpha: 0.10 + 0.05 * warm,
      warmBottomAlpha: 0.18 + 0.14 * warm,
      glowAlpha: 0.13 * glow,
      glowScale: 0.97 + 0.06 * glow,
      logoOpacity: enter,
      logoOffsetY: lerp(18, 0, enter),
      logoScale: lerp(0.968, 1, enter),
      logoShadowY: 10 + 6 * glow,
      logoShadowBlur: 24 + 14 * glow,
      logoShadowAlpha: 0.06 + 0.06 * glow,
      taglineOpacity: tagline,
      taglineOffsetY: (1 - tagline) * 14,
      taglineTrackingEm: lerp(0.024, -0.012, tagline),
      trackAlpha: 0.085 * smooth(clamp01((now - loaderStart) / loaderFade)),
      pillOpacity: loader.opacity,
      pillProgress: loader.progress
    )
  }

  private static func loader(at now: Double) -> (opacity: Double, progress: Double) {
    let sweep = entranceDuration - loaderStart
    if now <= entranceDuration {
      return (
        smooth(clamp01((now - loaderStart) / loaderFade)),
        smooth(clamp01((now - loaderStart) / sweep))
      )
    }
    let held = now - entranceDuration
    if held < loopFadeOut {
      return (1 - smooth(held / loopFadeOut), 1)
    }
    let cycle = (held - loopFadeOut).truncatingRemainder(dividingBy: loopPeriod)
    let fadeIn = smooth(clamp01(cycle / loaderFade))
    let fadeOut = 1 - smooth(clamp01((cycle - loopFadeOutStart) / loopFadeOut))
    return (min(fadeIn, fadeOut), smooth(clamp01(cycle / sweep)))
  }

  // MARK: Easing

  // Control points and the curve parameter keep their textbook names.
  // swiftlint:disable identifier_name

  private static let easeLogo = cubicBezier(0.22, 0.61, 0.24, 1)
  private static let easeOutQuad = cubicBezier(0.25, 0.46, 0.45, 0.94)
  private static let easeOutCubic = cubicBezier(0.215, 0.61, 0.355, 1)

  private static func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }
  private static func lerp(_ from: Double, _ to: Double, _ t: Double) -> Double {
    from + (to - from) * t
  }
  private static func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }

  private static func cubicBezier(
    _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double
  ) -> @Sendable (Double) -> Double {
    @Sendable func coordinate(_ p1: Double, _ p2: Double, _ t: Double) -> Double {
      ((1 - 3 * p2 + 3 * p1) * t + (3 * p2 - 6 * p1)) * t * t + 3 * p1 * t
    }
    @Sendable func slope(_ p1: Double, _ p2: Double, _ t: Double) -> Double {
      (3 * (1 - 3 * p2 + 3 * p1) * t + 2 * (3 * p2 - 6 * p1)) * t + 3 * p1
    }
    return { x in
      var t = x
      for _ in 0..<6 {
        let error = coordinate(x1, x2, t) - x
        let derivative = slope(x1, x2, t)
        if abs(error) < 1e-6 || abs(derivative) < 1e-6 { break }
        t -= error / derivative
      }
      return coordinate(y1, y2, min(1, max(0, t)))
    }
  }
  // swiftlint:enable identifier_name
}
