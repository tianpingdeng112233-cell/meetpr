import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Tab 5 "我的" (spec 028 §6). V0.1 ships the growth-curve entry; profile
/// archive cards and settings land with the onboarding specs (032/033).
@available(iOS 17.0, macOS 14.0, *)
public struct MyProfileView: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository
  ) {
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
  }

  public var body: some View {
    NavigationStack {
      List {
        NavigationLink {
          GrowthCurveView(studentID: studentID, plans: plans, e1rm: e1rm)
        } label: {
          Label("成长曲线", systemImage: "chart.xyaxis.line")
            .font(Font.MeetPR.body)
        }
        .listRowBackground(Color.MeetPR.surface1)
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
      .navigationTitle("我的")
    }
  }
}
