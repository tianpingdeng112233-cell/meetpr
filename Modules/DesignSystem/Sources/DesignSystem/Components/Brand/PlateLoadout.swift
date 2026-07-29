import SwiftUI

/// ⛔️ FROZEN W0 view — compatibility quarantine, not a v3 component.
///
/// New code must use `PlateVisual`. This implementation preserves the exact
/// `2e46d52` rendering until the coach migration wave, then should be deleted.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct LegacyPlateLoadout: View {
  let plates: [Double]
  let showCollar: Bool

  init(plates: [Double], showCollar: Bool = true) {
    self.plates = plates
    self.showCollar = showCollar
  }

  var body: some View {
    HStack(spacing: MeetPRSpacing.zero) {
      barSegment(width: 64, height: 7, radius: 4, roundLeading: true, gradient: Self.shaft)
      RoundedRectangle(cornerRadius: MeetPRRadius.point3)
        .fill(Self.shoulder)
        .frame(width: 10, height: 36)
        .overlay(alignment: .trailing) {
          Rectangle().fill(Color(legacyPlateHex: 0x4B5563)).frame(width: 1)
        }
      HStack(spacing: MeetPRSpacing.point2) {
        ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
          LegacyPlateView(value: plate)
        }
      }
      .padding(.leading, MeetPRSpacing.point2)
      if showCollar {
        LegacyCollarView().padding(.leading, MeetPRSpacing.point2)
      }
      barSegment(width: 110, height: 15, radius: 7, roundLeading: false, gradient: Self.sleeve)
        .padding(.leading, MeetPRSpacing.point2)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 208)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityText(plates, showCollar: showCollar))
  }

  private func barSegment(
    width: CGFloat,
    height: CGFloat,
    radius: CGFloat,
    roundLeading: Bool,
    gradient: LinearGradient
  ) -> some View {
    UnevenRoundedRectangle(
      topLeadingRadius: roundLeading ? radius : 0,
      bottomLeadingRadius: roundLeading ? radius : 0,
      bottomTrailingRadius: roundLeading ? 0 : radius,
      topTrailingRadius: roundLeading ? 0 : radius
    )
    .fill(gradient)
    .frame(width: width, height: height)
  }

  private static let shaft = steelGradient([
    (0x9DA0A5, 0), (0xE6E8EC, 0.35), (0xC4C8CE, 0.65), (0x83878E, 1),
  ])
  private static let shoulder = steelGradient([
    (0x9DA0A5, 0), (0xEDEFF2, 0.30), (0xC9CDD3, 0.70), (0x888C93, 1),
  ])
  private static let sleeve = steelGradient([
    (0x8C8F94, 0), (0xEAECEF, 0.35), (0xC2C6CC, 0.65), (0x7F838A, 1),
  ])

  private static func steelGradient(_ stops: [(UInt32, Double)]) -> LinearGradient {
    LinearGradient(
      stops: stops.map {
        .init(color: Color(legacyPlateHex: $0.0), location: $0.1)
      },
      startPoint: .top,
      endPoint: .bottom
    )
  }

  static func load(perSide: Double) -> [Double] {
    let denominations: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    var remaining = perSide
    var output: [Double] = []
    for denomination in denominations {
      while remaining + 1e-6 >= denomination {
        output.append(denomination)
        remaining -= denomination
      }
    }
    return output
  }

  static func breakdown(_ plates: [Double]) -> [(plate: Double, count: Int)] {
    var result: [(plate: Double, count: Int)] = []
    for plate in plates {
      if let index = result.firstIndex(where: { $0.plate == plate }) {
        result[index].count += 1
      } else {
        result.append((plate: plate, count: 1))
      }
    }
    return result
  }

  static func breakdownText(_ plates: [Double]) -> String {
    breakdown(plates)
      .map { "\(format($0.plate))kg × \($0.count)" }
      .joined(separator: " · ")
  }

  static func format(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
  }

  static func accessibilityText(_ plates: [Double], showCollar: Bool) -> String {
    let base = "Loaded barbell, per side: " + breakdownText(plates)
    return showCollar ? base + " + 2.5kg collar" : base
  }
}

/// Frozen W0 public entry. New code must use `PlateVisual`.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct PlateLoadout: View {
  private let legacy: LegacyPlateLoadout

  public init(plates: [Double], showCollar: Bool = true) {
    legacy = LegacyPlateLoadout(plates: plates, showCollar: showCollar)
  }

  public var body: some View {
    legacy
  }

  public static func load(perSide: Double) -> [Double] {
    LegacyPlateLoadout.load(perSide: perSide)
  }

  public static func breakdown(_ plates: [Double]) -> [(plate: Double, count: Int)] {
    LegacyPlateLoadout.breakdown(plates)
  }

  public static func breakdownText(_ plates: [Double]) -> String {
    LegacyPlateLoadout.breakdownText(plates)
  }

  static func format(_ value: Double) -> String {
    LegacyPlateLoadout.format(value)
  }

  static func accessibilityText(_ plates: [Double], showCollar: Bool) -> String {
    LegacyPlateLoadout.accessibilityText(plates, showCollar: showCollar)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct LegacyPlateView: View {
  let value: Double

  var body: some View {
    RoundedRectangle(cornerRadius: MeetPRRadius.point5)
      .fill(gradient)
      .frame(width: spec.width, height: spec.height)
  }

  private var spec: (width: CGFloat, height: CGFloat) {
    switch value {
    case 25: return (10, 170)
    case 20: return (8, 170)
    case 15: return (8, 151)
    case 10: return (8, 123)
    case 5: return (8, 86)
    case 2.5: return (7, 72)
    default: return (5, 60)
    }
  }

  private var gradient: LinearGradient {
    let stops: [(UInt32, Double)]
    switch value {
    case 25:
      stops = [(0x6E2A26, 0), (0xBE5049, 0.12), (0xA6423C, 0.55), (0x5E241F, 1)]
    case 20:
      stops = [(0x182E52, 0), (0x3E6BB5, 0.12), (0x33599B, 0.55), (0x142644, 1)]
    case 15:
      stops = [(0x77621A, 0), (0xD3B446, 0.12), (0xB99A31, 0.55), (0x63500F, 1)]
    case 10:
      stops = [(0x173F24, 0), (0x3FA05C, 0.12), (0x2F8449, 0.55), (0x123420, 1)]
    case 5:
      stops = [(0x7A7A7A, 0), (0xF5F5F5, 0.14), (0xDCDCDC, 0.55), (0x6E6E6E, 1)]
    case 2.5:
      stops = [(0x1C1C1E, 0), (0x6B6B70, 0.14), (0x3A3A3E, 0.55), (0x141416, 1)]
    default:
      stops = [(0x6F7379, 0), (0xF0F2F5, 0.14), (0xB9BDC4, 0.55), (0x565A60, 1)]
    }
    return LinearGradient(
      stops: stops.map {
        .init(color: Color(legacyPlateHex: $0.0), location: $0.1)
      },
      startPoint: .top,
      endPoint: .bottom
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct LegacyCollarView: View {
  private static let bodyColors = [
    Color(legacyPlateHex: 0x565A60),
    Color(legacyPlateHex: 0x9A9EA4),
    Color(legacyPlateHex: 0xF2F4F6),
    Color(legacyPlateHex: 0xD9DCE0),
    Color(legacyPlateHex: 0xAEB2B8),
    Color(legacyPlateHex: 0x84888E),
    Color(legacyPlateHex: 0x4A4E54),
  ]

  var body: some View {
    HStack(spacing: MeetPRSpacing.point1) {
      octagon
      nut
    }
    .overlay(alignment: .bottomLeading) { lever }
  }

  private var octagon: some View {
    LegacyOctagonShape()
      .fill(
        LinearGradient(
          stops: [
            .init(color: Self.bodyColors[0], location: 0),
            .init(color: Self.bodyColors[1], location: 0.16),
            .init(color: Self.bodyColors[2], location: 0.34),
            .init(color: Self.bodyColors[3], location: 0.50),
            .init(color: Self.bodyColors[4], location: 0.66),
            .init(color: Self.bodyColors[5], location: 0.84),
            .init(color: Self.bodyColors[6], location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .frame(width: 14, height: 44)
      .overlay {
        VStack(spacing: MeetPRSpacing.zero) {
          knurlLine(0.16, .black.opacity(0.35))
          knurlLine(0.18, .white.opacity(0.6))
          Spacer()
          knurlLine(0.32, .black.opacity(0.3))
          knurlLine(0.18, .black.opacity(0.4))
        }
        .frame(width: 14, height: 44)
      }
  }

  private func knurlLine(_ topFraction: CGFloat, _ color: Color) -> some View {
    Rectangle()
      .fill(color)
      .frame(height: MeetPRSpacing.point1)
      .padding(.top, MeetPRSpacing.minimumHitTarget * topFraction)
  }

  private var nut: some View {
    RoundedRectangle(cornerRadius: MeetPRRadius.point2)
      .fill(
        LinearGradient(
          colors: [
            Color(legacyPlateHex: 0x7F838A),
            Color(legacyPlateHex: 0xC9CDD3),
            Color(legacyPlateHex: 0x8F9399),
            Color(legacyPlateHex: 0x5E6268),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .frame(width: 15, height: 34)
      .overlay {
        HStack(spacing: MeetPRSpacing.point1AndHalf) {
          ForEach(0..<4, id: \.self) { _ in
            Rectangle().fill(.white.opacity(0.25)).frame(width: 0.5)
            Rectangle().fill(.black.opacity(0.25)).frame(width: 0.5)
          }
        }
      }
  }

  private var lever: some View {
    RoundedRectangle(cornerRadius: MeetPRRadius.point1AndHalf)
      .fill(
        LinearGradient(
          colors: [
            Color(legacyPlateHex: 0xD9DCE0),
            Color(legacyPlateHex: 0x84888F),
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: 3, height: 30)
      .overlay(alignment: .bottom) {
        RoundedRectangle(cornerRadius: MeetPRRadius.point1)
          .fill(
            LinearGradient(
              colors: [
                Color(legacyPlateHex: 0xB9BDC4),
                Color(legacyPlateHex: 0x6F7379),
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: 5, height: 7)
      }
      .rotationEffect(.degrees(-32), anchor: .top)
      .offset(x: 6, y: 22)
  }
}

private struct LegacyOctagonShape: Shape {
  func path(in rect: CGRect) -> Path {
    let inset = CGSize(width: rect.width * 0.2, height: rect.height * 0.16)
    var path = Path()
    path.move(to: CGPoint(x: inset.width, y: 0))
    path.addLine(to: CGPoint(x: rect.width - inset.width, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: inset.height))
    path.addLine(to: CGPoint(x: rect.width, y: rect.height - inset.height))
    path.addLine(to: CGPoint(x: rect.width - inset.width, y: rect.height))
    path.addLine(to: CGPoint(x: inset.width, y: rect.height))
    path.addLine(to: CGPoint(x: 0, y: rect.height - inset.height))
    path.addLine(to: CGPoint(x: 0, y: inset.height))
    path.closeSubpath()
    return path
  }
}

extension Color {
  fileprivate init(legacyPlateHex hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: 1
    )
  }
}
