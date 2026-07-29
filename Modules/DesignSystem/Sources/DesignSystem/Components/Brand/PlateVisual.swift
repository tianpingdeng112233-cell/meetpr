import SwiftUI

public struct Plate: Equatable, Sendable {
  public let weightKg: Double

  public init(weightKg: Double) {
    self.weightKg = weightKg
  }
}

/// Returns the plates loaded on one side of a 20kg bar.
///
/// Total weight is snapped to the NumberPad's 0.25kg contract and clamped to
/// 20...500kg. A competition collar contributes 2.5kg per side before the
/// standard 25/20/15/10/5/2.5/1.25kg greedy load is calculated.
public func plateBreakdown(totalKg: Double, hasCollar: Bool) -> [Plate] {
  let clamped = min(max(totalKg, 20), 500)
  let snapped = (clamped * 4).rounded() / 4
  let collarWeightPerSide = hasCollar ? 2.5 : 0
  let perSide = max(0, ((snapped - 20) / 2) - collarWeightPerSide)
  return greedyPlateLoad(perSide: perSide)
}

private func greedyPlateLoad(perSide: Double) -> [Plate] {
  let denominations = [25.0, 20, 15, 10, 5, 2.5, 1.25]
  var remaining = (perSide * 100).rounded() / 100
  var result: [Plate] = []

  for denomination in denominations {
    while remaining + 0.000_001 >= denomination {
      result.append(Plate(weightKg: denomination))
      remaining = ((remaining - denomination) * 100).rounded() / 100
    }
  }
  return result
}

/// SetEntry's loaded-barbell side view, translated from `SE_SPEC`/`SE_DIM`.
@MainActor
public struct PlateVisual: View {
  /// `SE_DIM`'s height for the barbell block.
  public static let standardHeight: CGFloat = 148

  private let plates: [Plate]
  private let hasCollar: Bool
  private let height: CGFloat

  /// - Parameter height: room the barbell gets. Defaults to the spec's 148pt;
  ///   pass less only where the surrounding screen would otherwise push its own
  ///   controls off a short display, and scale rather than crop.
  public init(totalKg: Double, hasCollar: Bool, height: CGFloat = PlateVisual.standardHeight) {
    self.plates = plateBreakdown(totalKg: totalKg, hasCollar: hasCollar)
    self.hasCollar = hasCollar
    self.height = height
  }

  public var body: some View {
    HStack(spacing: MeetPRSpacing.zero) {
      leftEndCap
      shoulder
      HStack(spacing: MeetPRSpacing.point1AndHalf) {
        ForEach(plates.indices, id: \.self) { index in
          PlateSideView(plate: plates[index])
        }
      }
      .padding(.leading, MeetPRSpacing.point2)

      if hasCollar {
        CollarSideView()
          .padding(.leading, MeetPRSpacing.point2)
      }

      rightShaft
        .padding(.leading, MeetPRSpacing.point2)
    }
    .frame(maxWidth: .infinity)
    // Drawn at spec size and scaled down as a whole, so every plate keeps its
    // relative width and thickness instead of being squashed or clipped.
    .frame(height: Self.standardHeight)
    .scaleEffect(height / Self.standardHeight, anchor: .center)
    .frame(height: height)
    .environment(\.layoutDirection, .leftToRight)
    .shadow(color: Color.MeetPR.plateDropShadow, radius: 4, y: 6)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityText(plates.map(\.weightKg), showCollar: hasCollar))
  }

  private var leftEndCap: some View {
    UnevenRoundedRectangle(
      topLeadingRadius: 5,
      bottomLeadingRadius: 5
    )
    .fill(
      LinearGradient(
        stops: Self.gradientStops(
          Color.MeetPR.barShaftGradient,
          locations: PlateVisualContract.shaftLocations
        ),
        startPoint: .top,
        endPoint: .bottom
      )
    )
    .frame(width: 58, height: 9)
  }

  private var shoulder: some View {
    RoundedRectangle(cornerRadius: 3)
      .fill(
        LinearGradient(
          stops: Self.gradientStops(
            Color.MeetPR.barShoulderGradient,
            locations: PlateVisualContract.shoulderLocations
          ),
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .frame(width: 11, height: 37)
      .overlay(alignment: .trailing) {
        Rectangle()
          .fill(Color.MeetPR.steelDarkEdge)
          .frame(width: 1)
          .padding(.vertical, MeetPRSpacing.point1)
      }
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(Color.MeetPR.steelLightEdge)
          .frame(width: 1)
          .padding(.vertical, MeetPRSpacing.point1)
          .padding(.leading, MeetPRSpacing.point1)
      }
      .shadow(color: Color.MeetPR.barDropShadow, radius: 1.5, y: 1)
  }

  private var rightShaft: some View {
    UnevenRoundedRectangle(
      bottomTrailingRadius: 2,
      topTrailingRadius: 2
    )
    .fill(
      LinearGradient(
        stops: Self.gradientStops(
          Color.MeetPR.barSleeveGradient,
          locations: PlateVisualContract.sleeveLocations
        ),
        startPoint: .top,
        endPoint: .bottom
      )
    )
    .frame(width: 92, height: 17)
    .shadow(color: Color.MeetPR.barDropShadow, radius: 1.5, y: 1)
  }

  public static func load(perSide: Double) -> [Double] {
    greedyPlateLoad(perSide: perSide).map(\.weightKg)
  }

  public static func breakdown(_ plates: [Double]) -> [(plate: Double, count: Int)] {
    var result: [(plate: Double, count: Int)] = []
    for plate in plates {
      if result.last?.plate == plate {
        result[result.count - 1].count += 1
      } else {
        result.append((plate: plate, count: 1))
      }
    }
    return result
  }

  public static func breakdownText(_ plates: [Double]) -> String {
    breakdown(plates)
      .map { "\(numberText($0.plate))kg × \($0.count)" }
      .joined(separator: " · ")
  }

  static func accessibilityText(_ plates: [Double], showCollar: Bool) -> String {
    guard !plates.isEmpty else {
      return showCollar ? "仅 2.5kg 赛扣" : "空杠 20kg"
    }

    let base = breakdownText(plates)
    return showCollar ? "\(base) + 2.5kg 赛扣" : base
  }

  fileprivate static func gradientStops(
    _ colors: [Color],
    locations: [CGFloat]
  ) -> [Gradient.Stop] {
    zip(colors, locations).map { color, location in
      Gradient.Stop(color: color, location: location)
    }
  }

  fileprivate static func numberText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

@MainActor
private struct PlateSideView: View {
  let plate: Plate

  var body: some View {
    RoundedRectangle(cornerRadius: MeetPRRadius.micro)
      .fill(
        LinearGradient(
          stops: PlateVisual.gradientStops(
            colors,
            locations: PlateVisualContract.plateLocations
          ),
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .frame(width: dimensions.width, height: dimensions.height)
      .shadow(color: Color.MeetPR.plateDropShadow, radius: 2.5, x: 2)
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(Color.MeetPR.plateInnerHighlight)
          .frame(width: 1)
          .padding(.vertical, MeetPRSpacing.point1)
      }
      .overlay(alignment: .trailing) {
        Rectangle()
          .fill(Color.MeetPR.plateInnerShade)
          .frame(width: 1.5)
          .padding(.vertical, MeetPRSpacing.point1)
      }
  }

  private var dimensions: CGSize {
    let source =
      PlateVisualContract.seDimensions[plate.weightKg]
      ?? PlateVisualContract.seDimensions[1.25]
      ?? .init(width: 5, height: 48)
    return CGSize(width: source.width, height: source.height)
  }

  private var colors: [Color] {
    switch plate.weightKg {
    case 25: Color.MeetPR.plate25Gradient
    case 20: Color.MeetPR.plate20Gradient
    case 15: Color.MeetPR.plate15Gradient
    case 10: Color.MeetPR.plate10Gradient
    case 5: Color.MeetPR.plate5Gradient
    case 2.5: Color.MeetPR.plate2Point5Gradient
    default: Color.MeetPR.plate1Point25Gradient
    }
  }
}

@MainActor
private struct CollarSideView: View {
  var body: some View {
    HStack(spacing: MeetPRSpacing.point1) {
      Octagon()
        .fill(
          LinearGradient(
            stops: PlateVisual.gradientStops(
              Color.MeetPR.collarBodyGradient,
              locations: PlateVisualContract.collarBodyLocations
            ),
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 11, height: 35)
        .shadow(color: Color.MeetPR.plateInnerShade, radius: 1.5, x: 1)

      RoundedRectangle(cornerRadius: MeetPRRadius.micro)
        .fill(
          LinearGradient(
            stops: PlateVisual.gradientStops(
              Color.MeetPR.collarNutGradient,
              locations: PlateVisualContract.collarNutLocations
            ),
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 14, height: 27)
        .overlay {
          HStack(spacing: MeetPRSpacing.zero) {
            ForEach(0..<7, id: \.self) { _ in
              Rectangle()
                .fill(Color.MeetPR.collarKnurlDark)
                .frame(width: 1)
              Rectangle()
                .fill(Color.MeetPR.collarKnurlLight)
                .frame(width: 1)
            }
          }
          .clipped()
        }
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.micro)
            .stroke(Color.MeetPR.collarNutInsetShade, lineWidth: 2)
            .blur(radius: 1)
            .offset(x: -1)
            .clipShape(.rect(cornerRadius: MeetPRRadius.micro))
        }
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.micro)
            .stroke(Color.MeetPR.collarNutInsetHighlight, lineWidth: 1)
            .blur(radius: 0.5)
            .offset(x: 1)
            .clipShape(.rect(cornerRadius: MeetPRRadius.micro))
        }
        .shadow(color: Color.MeetPR.barDropShadow, radius: 1.5, x: 1)
    }
    .overlay(alignment: .topLeading) {
      lever
        .offset(
          x: PlateVisualContract.collarLeverLeft,
          y: PlateVisualContract.collarLeverTop
        )
    }
  }

  private var lever: some View {
    RoundedRectangle(cornerRadius: MeetPRRadius.micro)
      .fill(
        LinearGradient(
          gradient: Gradient(
            stops: PlateVisual.gradientStops(
              Color.MeetPR.collarLeverGradient,
              locations: PlateVisualContract.leverLocations
            )
          ),
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: 3, height: 27)
      .overlay(alignment: .bottom) {
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(
                stops: PlateVisual.gradientStops(
                  Color.MeetPR.collarKnobGradient,
                  locations: PlateVisualContract.knobLocations
                )
              ),
              center: UnitPoint(x: 0.35, y: 0.30),
              startRadius: 0,
              endRadius: 5
            )
          )
          .frame(width: MeetPRSpacing.space2, height: MeetPRSpacing.space2)
          .offset(y: MeetPRSpacing.point3)
      }
      .rotationEffect(.degrees(-34), anchor: .top)
      .shadow(color: Color.MeetPR.barDropShadow, radius: 1, y: 1)
  }
}

private struct Octagon: Shape {
  func path(in rect: CGRect) -> Path {
    let horizontal = rect.width * 0.25
    let vertical = rect.height * 0.14
    var path = Path()
    path.move(to: CGPoint(x: horizontal, y: 0))
    path.addLine(to: CGPoint(x: rect.width - horizontal, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: vertical))
    path.addLine(to: CGPoint(x: rect.width, y: rect.height - vertical))
    path.addLine(to: CGPoint(x: rect.width - horizontal, y: rect.height))
    path.addLine(to: CGPoint(x: horizontal, y: rect.height))
    path.addLine(to: CGPoint(x: 0, y: rect.height - vertical))
    path.addLine(to: CGPoint(x: 0, y: vertical))
    path.closeSubpath()
    return path
  }
}
