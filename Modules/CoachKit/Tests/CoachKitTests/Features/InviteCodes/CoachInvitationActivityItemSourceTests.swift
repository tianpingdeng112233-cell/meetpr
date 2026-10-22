#if os(iOS)
  import Foundation
  import LinkPresentation
  import Testing
  import UIKit

  @testable import CoachKit

  @MainActor
  @Test func invitationActivitySharesOneURLOrCompleteTextWithPreview() throws {
    let code = "XK7MPQ2RVT"
    let source = CoachInvitationActivityItemSource(code: code, coachName: "Alex")
    let controller = UIActivityViewController(activityItems: [source], applicationActivities: nil)
    let inviteURL = CoachInvitationMessage.inviteURL(code: code)

    #expect(source.activityViewControllerPlaceholderItem(controller) as? URL == inviteURL)
    for activity: UIActivity.ActivityType? in [
      nil, UIActivity.ActivityType("com.tencent.xin.sharetimeline"),
      UIActivity.ActivityType("another.extension"), .airDrop,
    ] {
      #expect(
        source.activityViewController(controller, itemForActivityType: activity) as? URL
          == inviteURL)
    }
    for activity in [UIActivity.ActivityType.message, .mail, .copyToPasteboard] {
      let text = try #require(
        source.activityViewController(controller, itemForActivityType: activity) as? String)
      #expect(
        text == CoachInvitationMessage.text(code: code, coachName: "Alex", buildTrack: .china))
      #expect(text.contains(inviteURL.absoluteString))
    }

    let title = CoachInvitationMessage.shareTitle(coachName: "Alex")
    let metadata = try #require(source.activityViewControllerLinkMetadata(controller))
    #expect(metadata.title == title)
    #expect(metadata.originalURL == inviteURL)
    #expect(metadata.url == inviteURL)
    #expect(metadata.iconProvider?.canLoadObject(ofClass: UIImage.self) == true)
    #expect(source.activityViewController(controller, subjectForActivityType: .mail) == title)
  }
#endif
