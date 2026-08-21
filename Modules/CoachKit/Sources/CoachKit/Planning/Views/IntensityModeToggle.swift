import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct IntensityModeToggle: View {
  @Binding private var mode: IntensityMode

  public init(mode: Binding<IntensityMode>) {
    self._mode = mode
  }

  public var body: some View {
    Picker(CoachPlanningStrings.intensityMode, selection: $mode) {
      Text(CoachPlanningStrings.weight).tag(IntensityMode.weight)
      Text("RPE").tag(IntensityMode.rpe)
    }
    .pickerStyle(.segmented)
    .font(Font.MeetPR.footnote)
    .accessibilityLabel(CoachPlanningStrings.intensityMode)
  }
}
