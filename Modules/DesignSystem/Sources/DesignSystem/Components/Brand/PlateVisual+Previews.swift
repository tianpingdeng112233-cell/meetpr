import SwiftUI

#Preview("PlateVisual · Empty + Loaded · Dark") {
  VStack(spacing: MeetPRSpacing.space4) {
    PlateVisual(totalKg: 20, hasCollar: false)
    PlateVisual(totalKg: 175, hasCollar: false)
    PlateVisual(totalKg: 175, hasCollar: true)
  }
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("PlateVisual · Empty + Loaded · Light") {
  VStack(spacing: MeetPRSpacing.space4) {
    PlateVisual(totalKg: 20, hasCollar: false)
    PlateVisual(totalKg: 175, hasCollar: false)
    PlateVisual(totalKg: 175, hasCollar: true)
  }
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
