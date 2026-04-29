import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct CoachRootView: View {
  @State private var showPlanning = false

  public init() {}

  public var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        Text("教练端")
          .font(Font.MeetPR.title1)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        PrimaryButton("排新计划", isFullWidth: true) {
          showPlanning = true
        }
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color.MeetPR.bg)
      .navigationTitle("MeetPR")
      #if os(iOS)
        .fullScreenCover(isPresented: $showPlanning) {
          PlanningCoordinatorView(
            repository: InMemoryPlanRepository.preview(),
            draftStore: DraftStore.shared
          )
        }
      #else
        .sheet(isPresented: $showPlanning) {
          PlanningCoordinatorView(
            repository: InMemoryPlanRepository.preview(),
            draftStore: DraftStore.shared
          )
        }
      #endif
    }
  }
}
