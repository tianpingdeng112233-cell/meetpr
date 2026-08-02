import CoreGraphics

/// Plate and collar geometry transcribed from `SE_SPEC`/`SE_DIM`, kept beside
/// `PlateVisual` so the drawing code stays readable and the contract tests have
/// one place to assert against.
struct PlateSourceDimensions: Equatable, Sendable {
  let width: CGFloat
  let height: CGFloat
}

enum PlateVisualContract {
  static let seSpecDimensions: [Double: PlateSourceDimensions] = [
    25: .init(width: 12, height: 135),
    20: .init(width: 11, height: 135),
    15: .init(width: 11, height: 120),
    10: .init(width: 9, height: 98),
    5: .init(width: 9, height: 68),
    2.5: .init(width: 8, height: 57),
    1.25: .init(width: 7, height: 48),
  ]

  static let seDimensions: [Double: PlateSourceDimensions] = [
    25: .init(width: 11, height: 135),
    20: .init(width: 8, height: 135),
    15: .init(width: 8, height: 120),
    10: .init(width: 8, height: 98),
    5: .init(width: 8, height: 68),
    2.5: .init(width: 6, height: 57),
    1.25: .init(width: 5, height: 48),
  ]

  static let plateLocations: [CGFloat] = [0, 0.04, 0.15, 0.22, 0.46, 0.68, 0.90, 1]
  static let shaftLocations: [CGFloat] = [0, 0.14, 0.34, 0.44, 0.60, 0.78, 1]
  static let shoulderLocations: [CGFloat] = [0, 0.16, 0.40, 0.62, 0.80, 1]
  static let sleeveLocations: [CGFloat] = [0, 0.15, 0.36, 0.46, 0.62, 0.80, 1]
  static let collarBodyLocations: [CGFloat] = [0, 0.15, 0.33, 0.42, 0.58, 0.76, 1]
  static let collarNutLocations: [CGFloat] = [0, 0.16, 0.36, 0.44, 0.58, 0.78, 1]
  static let leverLocations: [CGFloat] = [0, 0.45, 1]
  static let knobLocations: [CGFloat] = [0, 0.58, 1]
  static let collarLeverLeft: CGFloat = 8
  static let collarLeverTop: CGFloat = 17
}
