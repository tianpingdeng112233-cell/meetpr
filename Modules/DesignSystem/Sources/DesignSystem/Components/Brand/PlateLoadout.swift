import SwiftUI

/// A loaded-barbell visualization: full-width steel bar + sleeve stopper +
/// IPF-colored plate stack (heavy → light from the inside) + an optional 2.5kg
/// locking collar (shown when `showCollar`) + sleeve end. Reproduces the user's
/// plate-calculator reference.
///
/// `plates` is one side's load, heaviest first (e.g. `[25, 25, 25, 5, 1.25]`).
/// Plate colors are **IPF domain constants**, intentionally not theme tokens.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct PlateLoadout: View {
  private let plates: [Double]
  private let showCollar: Bool

  public init(plates: [Double], showCollar: Bool = true) {
    self.plates = plates
    self.showCollar = showCollar
  }

  private static let steel = [
    Color(plateHex: 0x6B7280), Color(plateHex: 0xE5E7EB), Color(plateHex: 0x6B7280),
  ]

  public var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(LinearGradient(colors: Self.steel, startPoint: .top, endPoint: .bottom))
        .frame(height: 16)
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.5), radius: 4, y: 4)

      HStack(alignment: .center, spacing: 1) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(plateHex: 0x9CA3AF))
          .frame(width: 12, height: 48)
          .overlay(alignment: .trailing) {
            Rectangle().fill(Color(plateHex: 0x4B5563)).frame(width: 1)
          }
        ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in PlateView(value: plate) }
        if showCollar {
          CollarView().padding(.leading, 4)
        }
        Spacer(minLength: 0)
      }
      .padding(.leading, 56)

      HStack {
        Spacer()
        Capsule().fill(Color(plateHex: 0x6B7280)).frame(width: 12, height: 16)
      }
      .padding(.trailing, 4)
    }
    .frame(height: 208)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityText(plates))
  }

  // MARK: - Plate math (biggest-first). The 2.5kg locking collar is counted by callers.

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

@available(iOS 17.0, macOS 14.0, *)
private struct PlateView: View {
  let value: Double
  var body: some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(fill)
      .frame(width: size.w, height: size.h)
      .overlay {
        RoundedRectangle(cornerRadius: 4)
          .fill(
            LinearGradient(
              colors: [.clear, .black.opacity(0.3)], startPoint: .center, endPoint: .trailing))
      }
      .overlay { RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.2), lineWidth: 1) }
  }
  private var size: (w: CGFloat, h: CGFloat) {
    switch value {
    case 25, 20: return (24, 192)
    case 15, 10: return (16, 160)
    case 5: return (12, 128)
    case 2.5: return (8, 96)
    default: return (6, 80)
    }
  }
  private var fill: AnyShapeStyle {
    switch value {
    case 25: return AnyShapeStyle(Color(plateHex: 0xBA1A20))
    case 20: return AnyShapeStyle(Color(plateHex: 0x006EC9))
    case 15: return AnyShapeStyle(Color(plateHex: 0xF8BD2A))
    case 10: return AnyShapeStyle(Color(plateHex: 0x16A34A))
    case 5: return AnyShapeStyle(Color.white)
    case 2.5:
      return AnyShapeStyle(
        LinearGradient(
          colors: [
            Color(plateHex: 0x111827), Color(plateHex: 0x1F2937), Color(plateHex: 0x111827),
          ], startPoint: .leading, endPoint: .trailing))
    default: return AnyShapeStyle(Color(plateHex: 0xD1D5DB))
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CollarView: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(
        LinearGradient(
          colors: [
            Color(plateHex: 0x9CA3AF), Color(plateHex: 0xE5E7EB), Color(plateHex: 0x6B7280),
          ], startPoint: .top, endPoint: .bottom)
      )
      .frame(width: 16, height: 48)
      .overlay {
        RoundedRectangle(cornerRadius: 4)
          .fill(
            LinearGradient(
              colors: [.clear, .black.opacity(0.3)], startPoint: .center, endPoint: .trailing))
      }
      .overlay { RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.4), lineWidth: 1) }
      .overlay(alignment: .bottom) {
        ZStack(alignment: .bottom) {
          Capsule().fill(Color(plateHex: 0x9CA3AF)).frame(width: 4, height: 24).offset(y: 16)
          Circle().fill(Color(plateHex: 0x4B5563)).frame(width: 8, height: 8).offset(y: 20)
        }
      }
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
    PlateLoadout(plates: PlateLoadout.load(perSide: 78.75))
    Text(PlateLoadout.breakdownText(PlateLoadout.load(perSide: 78.75)))
      .font(.system(size: 14, weight: .semibold, design: .monospaced))
      .foregroundStyle(Color.MeetPR.fgPrimary)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}
