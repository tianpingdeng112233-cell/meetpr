import DesignSystem
import SwiftUI

struct VideoFailureBanner: View {
  let count: Int
  var historical = false
  let retry: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Image(systemName: "exclamationmark.triangle.fill")
      Text(
        StudentStrings.replacing(
          historical ? .videoFailureHistory : .videoFailureBanner, values: [String(count)])
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
      Button(
        StudentStrings.localized(historical ? .videoAttachmentV3Controls009 : .videoRetryNow),
        action: retry
      )
      .font(.callout.bold())
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .font(.footnote)
    .foregroundStyle(Color.MeetPR.danger)
    .padding(.horizontal, MeetPRSpacing.space3)
    .background(Color.MeetPR.dangerSoft, in: .rect(cornerRadius: MeetPRRadius.control))
    .accessibilityIdentifier("videoDelivery.failureBanner")
  }
}
