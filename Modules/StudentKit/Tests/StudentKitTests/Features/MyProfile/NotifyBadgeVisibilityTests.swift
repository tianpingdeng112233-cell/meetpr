import CoreModels
import Testing

@testable import StudentKit

// U11-a (spec 046 §3 零教练字样): the 「通知教练」badge must never appear for a
// solo Free-tier student — they have no coach to notify.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func notifyBadgeHiddenForSoloEvenOnPushRows() {
  #expect(MyProfileView.showsNotifyBadge(push: true, trainingMode: .selfTrain) == false)
  #expect(MyProfileView.showsNotifyBadge(push: false, trainingMode: .selfTrain) == false)
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func notifyBadgeShownForCoachedPushRowsOnly() {
  #expect(MyProfileView.showsNotifyBadge(push: true, trainingMode: .coached) == true)
  #expect(MyProfileView.showsNotifyBadge(push: false, trainingMode: .coached) == false)
}

// U12 (spec 046 §3 / 047 AC#3): coach feedback history must be structurally
// gated out of solo.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func coachSurfacesHiddenForSolo() {
  #expect(TrainingHistoryView.showsCoachFeedback(trainingMode: .selfTrain) == false)
  #expect(TrainingHistoryView.showsCoachFeedback(trainingMode: .coached) == true)
}
