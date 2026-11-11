import SwiftUI

#Preview("NumberPad · Weight + Reps · Dark") {
  VStack(spacing: MeetPRSpacing.space4) {
    MeetPRNumberPad(field: .weight, value: 175, onCommit: { _ in }, onCancel: {})
    MeetPRNumberPad(field: .reps, value: 3, onCommit: { _ in }, onCancel: {})
  }
  .background(Color.MeetPR.bgInset)
  .preferredColorScheme(.dark)
}

#Preview("NumberPad · Weight + Reps · Light") {
  VStack(spacing: MeetPRSpacing.space4) {
    MeetPRNumberPad(field: .weight, value: 175, onCommit: { _ in }, onCancel: {})
    MeetPRNumberPad(field: .reps, value: 3, onCommit: { _ in }, onCancel: {})
  }
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
