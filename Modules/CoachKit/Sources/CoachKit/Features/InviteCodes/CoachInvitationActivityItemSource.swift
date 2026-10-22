#if os(iOS)
  import LinkPresentation
  import UIKit

  /// Share extensions receive one URL; text-friendly system activities receive one message.
  final class CoachInvitationActivityItemSource: NSObject, UIActivityItemSource {
    private let inviteURL: URL
    private let message: String
    private let title: String

    init(code: String, coachName: String?) {
      inviteURL = CoachInvitationMessage.inviteURL(code: code)
      message = CoachInvitationMessage.text(code: code, coachName: coachName, buildTrack: .china)
      title = CoachInvitationMessage.shareTitle(coachName: coachName)
      super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController)
      -> Any
    {
      inviteURL
    }

    func activityViewController(
      _ activityViewController: UIActivityViewController,
      itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
      switch activityType {
      case .message, .mail, .copyToPasteboard:
        message
      default:
        inviteURL
      }
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController)
      -> LPLinkMetadata?
    {
      let metadata = LPLinkMetadata()
      metadata.title = title
      metadata.originalURL = inviteURL
      metadata.url = inviteURL
      if let icon = UIImage(named: "InviteShareIcon", in: .module, compatibleWith: nil) {
        metadata.iconProvider = NSItemProvider(object: icon)
      }
      return metadata
    }

    func activityViewController(
      _ activityViewController: UIActivityViewController,
      subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
      title
    }
  }
#endif
