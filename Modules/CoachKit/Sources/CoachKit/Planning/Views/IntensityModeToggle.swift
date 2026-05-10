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
    Picker("强度模式", selection: $mode) {
      Text("重量").tag(IntensityMode.weight)
      Text("RPE").tag(IntensityMode.rpe)
    }
    .pickerStyle(.segmented)
    .font(Font.MeetPR.footnote)
    .accessibilityLabel("强度模式")
  }
}
