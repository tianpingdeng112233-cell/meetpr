import SwiftUI

/// A loaded-barbell visualization: full-width steel bar + sleeve stopper +
/// IPF-colored plate stack (heavy → light from the inside) + an optional
/// competition collar (赛扣, shown when `showCollar`) + sleeve end.
///
/// Plate diameters (height) and thicknesses (width) are drawn to the real IPF
/// side-view proportions the user specified (`杠铃片规格`): Φ450/450/400/325/228/
/// 190/160 mm and 27/22/22/22/26/19/12 mm, so 15 kg and 10 kg no longer share a
/// height. Plate colours + the cylinder shading gradients are **IPF domain
/// constants**, intentionally not theme tokens.
///
/// `plates` is one side's load, heaviest first (e.g. `[25, 25, 25, 5, 1.25]`).
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct PlateLoadout: View {
  private let plates: [Double]
  private let showCollar: Bool

  public init(plates: [Double], showCollar: Bool = true) {
    self.plates = plates
    self.showCollar = showCollar
  }

  // The bar is drawn as two visible segments (the plates cover the span
  // between them): a thin shaft stub on the inside and a thicker sleeve end
  // outboard of the collar. The whole assembly is centered so both ends inset
  // from the edges — the sleeve "truncates" a little short on the right.
  public var body: some View {
    HStack(spacing: 0) {
      barSegment(width: 64, height: 7, radius: 4, roundLeading: true, gradient: Self.shaft)
      // Sleeve shoulder / stopper the plates seat against.
      RoundedRectangle(cornerRadius: 3)
        .fill(Self.shoulder)
        .frame(width: 10, height: 36)
        .overlay(alignment: .trailing) {
          Rectangle().fill(Color(plateHex: 0x4B5563)).frame(width: 1)
        }
      HStack(spacing: 2) {
        ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in PlateView(value: plate) }
      }
      .padding(.leading, 2)
      if showCollar {
        CollarView().padding(.leading, 2)
      }
      barSegment(width: 110, height: 15, radius: 7, roundLeading: false, gradient: Self.sleeve)
        .padding(.leading, 2)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 208)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityText(plates))
  }

  /// One end of the steel bar; rounded on the outward end only.
  private func barSegment(
    width: CGFloat, height: CGFloat, radius: CGFloat, roundLeading: Bool, gradient: LinearGradient
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
      stops: stops.map { .init(color: Color(plateHex: $0.0), location: $0.1) },
      startPoint: .top, endPoint: .bottom)
  }

  // MARK: - Plate math (biggest-first). The 2.5kg competition collar is counted by callers.

  /// Greedily loads one side from standard IPF denominations, heaviest first.
  public static func load(perSide: Double) -> [Double] {
    let denominations: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    var remaining = perSide
    var out: [Double] = []
    for denomination in denominations {
      while remaining + 1e-6 >= denomination {
        out.append(denomination)
        remaining -= denomination
      }
    }
    return out
  }

  /// Groups a plate list into `(value, count)` pairs preserving heavy-first order.
  public static func breakdown(_ plates: [Double]) -> [(plate: Double, count: Int)] {
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

  /// "25kg × 3 · 5kg × 1 · 1.25kg × 1"
  public static func breakdownText(_ plates: [Double]) -> String {
    breakdown(plates).map { "\(format($0.plate))kg × \($0.count)" }.joined(separator: " · ")
  }

  static func format(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
  }

  private static func accessibilityText(_ plates: [Double]) -> String {
    "Loaded barbell, per side: " + breakdownText(plates)
  }
}

// MARK: - Single plate (real Φ / thickness proportions + cylinder shading)

@available(iOS 17.0, macOS 14.0, *)
private struct PlateView: View {
  let value: Double
  var body: some View {
    // Radius 5 + no outline: the plate is just the gradient bar, exactly as the
    // 杠铃片规格 cards draw it; the 2pt inter-plate gap gives the separation.
    RoundedRectangle(cornerRadius: 5)
      .fill(gradient)
      .frame(width: spec.w, height: spec.h)
  }

  /// (width = thickness, height = diameter), in points, to the `杠铃片规格` scale.
  private var spec: (w: CGFloat, h: CGFloat) {
    switch value {
    case 25: return (10, 170)  // Φ450 · 27mm
    case 20: return (8, 170)  // Φ450 · 22mm
    case 15: return (8, 151)  // Φ400 · 22mm
    case 10: return (8, 123)  // Φ325 · 22mm
    case 5: return (8, 86)  // Φ228 · 26mm
    case 2.5: return (7, 72)  // Φ190 · 19mm
    default: return (5, 60)  // 1.25 — Φ160 · 12mm
    }
  }

  /// Vertical 4-stop gradient: rim shadow → highlight → body → base shadow.
  private var gradient: LinearGradient {
    let stops: [(UInt32, Double)]
    switch value {
    case 25: stops = [(0x6E2A26, 0), (0xBE5049, 0.12), (0xA6423C, 0.55), (0x5E241F, 1)]
    case 20: stops = [(0x182E52, 0), (0x3E6BB5, 0.12), (0x33599B, 0.55), (0x142644, 1)]
    case 15: stops = [(0x77621A, 0), (0xD3B446, 0.12), (0xB99A31, 0.55), (0x63500F, 1)]
    case 10: stops = [(0x173F24, 0), (0x3FA05C, 0.12), (0x2F8449, 0.55), (0x123420, 1)]
    case 5: stops = [(0x7A7A7A, 0), (0xF5F5F5, 0.14), (0xDCDCDC, 0.55), (0x6E6E6E, 1)]
    case 2.5: stops = [(0x1C1C1E, 0), (0x6B6B70, 0.14), (0x3A3A3E, 0.55), (0x141416, 1)]
    default: stops = [(0x6F7379, 0), (0xF0F2F5, 0.14), (0xB9BDC4, 0.55), (0x565A60, 1)]
    }
    return LinearGradient(
      stops: stops.map { .init(color: Color(plateHex: $0.0), location: $0.1) },
      startPoint: .top, endPoint: .bottom)
  }
}

// MARK: - Competition collar (赛扣): octagonal knurled body + nut + lever

@available(iOS 17.0, macOS 14.0, *)
private struct CollarView: View {
  private static let body = [
    Color(plateHex: 0x565A60), Color(plateHex: 0x9A9EA4), Color(plateHex: 0xF2F4F6),
    Color(plateHex: 0xD9DCE0), Color(plateHex: 0xAEB2B8), Color(plateHex: 0x84888E),
    Color(plateHex: 0x4A4E54),
  ]

  var body: some View {
    HStack(spacing: 1) {
      octagon
      nut
    }
    .overlay(alignment: .bottomLeading) { lever }
  }

  private var octagon: some View {
    OctagonShape()
      .fill(
        LinearGradient(
          stops: [
            .init(color: Self.body[0], location: 0), .init(color: Self.body[1], location: 0.16),
            .init(color: Self.body[2], location: 0.34), .init(color: Self.body[3], location: 0.50),
            .init(color: Self.body[4], location: 0.66), .init(color: Self.body[5], location: 0.84),
            .init(color: Self.body[6], location: 1),
          ], startPoint: .top, endPoint: .bottom)
      )
      .frame(width: 14, height: 44)
      .overlay {
        // Knurl rings.
        VStack(spacing: 0) {
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
    Rectangle().fill(color).frame(height: 1).padding(.top, 44 * topFraction)
  }

  private var nut: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(
        LinearGradient(
          colors: [
            Color(plateHex: 0x7F838A), Color(plateHex: 0xC9CDD3), Color(plateHex: 0x8F9399),
            Color(plateHex: 0x5E6268),
          ], startPoint: .top, endPoint: .bottom)
      )
      .frame(width: 15, height: 34)
      .overlay {
        HStack(spacing: 1.5) {
          ForEach(0..<4, id: \.self) { _ in
            Rectangle().fill(.white.opacity(0.25)).frame(width: 0.5)
            Rectangle().fill(.black.opacity(0.25)).frame(width: 0.5)
          }
        }
      }
  }

  /// The clamp lever, hinged near the nut and swung down-left.
  private var lever: some View {
    RoundedRectangle(cornerRadius: 1.5)
      .fill(
        LinearGradient(
          colors: [Color(plateHex: 0xD9DCE0), Color(plateHex: 0x84888F)],
          startPoint: .leading, endPoint: .trailing)
      )
      .frame(width: 3, height: 30)
      .overlay(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 1)
          .fill(
            LinearGradient(
              colors: [Color(plateHex: 0xB9BDC4), Color(plateHex: 0x6F7379)],
              startPoint: .leading, endPoint: .trailing)
          )
          .frame(width: 5, height: 7)
      }
      .rotationEffect(.degrees(-32), anchor: .top)
      .offset(x: 6, y: 22)
  }
}

private struct OctagonShape: Shape {
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
  fileprivate init(plateHex hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: 1)
  }
}

#Preview("PlateLoadout") {
  VStack(spacing: 24) {
    PlateLoadout(plates: PlateLoadout.load(perSide: 72.5))
    Text(PlateLoadout.breakdownText(PlateLoadout.load(perSide: 72.5)))
      .font(.system(size: 14, weight: .semibold, design: .monospaced))
      .foregroundStyle(Color.MeetPR.fgPrimary)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}
