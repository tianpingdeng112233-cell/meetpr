import Foundation

enum ChatStrings {
  static let messages = localized("chat.messages")
  static let noConversations = localized("chat.noConversations")
  static let noMessages = localized("chat.noMessages")
  static let noMessagesDescription = localized("chat.noMessagesDescription")
  static let loadingMessages = localized("chat.loadingMessages")
  static let loadMessagesFailed = localized("chat.loadMessagesFailed")
  static let image = localized("chat.image")
  static let imageUnavailable = localized("chat.imageUnavailable")
  static let sending = localized("chat.sending")
  static let sendFailed = localized("chat.sendFailed")
  static let retry = localized("chat.retry")
  static let delivered = localized("chat.delivered")
  static let read = localized("chat.read")
  static let composerPlaceholder = localized("chat.composerPlaceholder")
  static let send = localized("chat.send")
  static let choosePhoto = localized("chat.choosePhoto")
  static let cancel = localized("chat.cancel")
  static let close = localized("chat.close")
  static let closePlayback = localized("chat.closePlayback")
  static let closeAnnotation = localized("chat.closeAnnotation")
  static let loadOlder = localized("chat.loadOlder")
  static let preparingImage = localized("chat.preparingImage")
  static let imagePreparationFailed = localized("chat.imagePreparationFailed")
  static let unread = localized("chat.unread")
  static let trainingShare = localized("chat.trainingShare")
  static let setNumber = localized("chat.setNumber")
  static let load = localized("chat.load")
  static let playVideo = localized("chat.playVideo")
  static let playPlayback = localized("chat.playPlayback")
  static let pausePlayback = localized("chat.pausePlayback")
  static let videoPlayback = localized("chat.videoPlayback")
  static let collapseVideoBadge = localized("chat.videoBadge.collapse")
  static let expandVideoBadge = localized("chat.videoBadge.expand")
  static let videoBadgeSetPrefix = localized("chat.videoBadge.setPrefix")
  static let videoBadgeSetSuffix = localized("chat.videoBadge.setSuffix")
  static let coachExportConfirmationTitle = localized(
    "chat.videoExport.coachConfirmation.title")
  static let coachExportConfirmationMessage = localized(
    "chat.videoExport.coachConfirmation.message")
  static let coachExportConfirmationAction = localized(
    "chat.videoExport.coachConfirmation.action")
  static let videoExport = localized("chat.videoExport.action")
  static let videoExporting = localized("chat.videoExport.exporting")
  static let videoExportSaved = localized("chat.videoExport.saved")
  static let videoExportFailed = localized("chat.videoExport.failed")
  static let videoExportFailureMessage = localized("chat.videoExport.failureMessage")
  static let videoExportPhotoPermissionDenied = localized(
    "chat.videoExport.photoPermissionDenied")
  static let videoMarker = localized("chat.videoMarker")
  static let videoMarkersFailed = localized("chat.videoMarkersFailed")
  static let addVideoMarker = localized("chat.addVideoMarker")
  static let playbackProgress = localized("chat.playbackProgress")
  static let playbackSpeed = localized("chat.playbackSpeed")
  static let selected = localized("chat.selected")
  static let playbackFailed = localized("chat.playbackFailed")
  static let refreshing = localized("chat.refreshing")
  static let addAttachment = localized("chat.addAttachment")
  static let back = localized("chat.back")
  static let continueSelection = localized("chat.continueSelection")
  static let continueToChat = localized("chat.continueToChat")
  static let includeVideo = localized("chat.includeVideo")
  static let invalidSetRecord = localized("chat.invalidSetRecord")
  static let messageTooLong = localized("chat.messageTooLong")
  static let noShareableSets = localized("chat.noShareableSets")
  static let noShareableSetsDescription = localized("chat.noShareableSetsDescription")
  static let loggedSetCardLabel = localized("chat.loggedSetCardLabel")
  static let plannedSetCardLabel = localized("chat.plannedSetCardLabel")
  static let rpeMetric = localized("chat.rpeMetric")
  static let removeTrainingShare = localized("chat.removeTrainingShare")
  static let sendCurrentSetRecord = localized("chat.sendCurrentSetRecord")
  static let sendCurrentSetPlan = localized("chat.sendCurrentSetPlan")
  static let setCardDelivered = localized("chat.setCardDelivered")
  static let setCardRead = localized("chat.setCardRead")
  static let setRefNotePlaceholder = localized("chat.setRefNotePlaceholder")
  static let shareTodayTraining = localized("chat.shareTodayTraining")
  static let completedSection = localized("chat.completedSection")
  static let todayPlanSection = localized("chat.todayPlanSection")
  static let trainingLoadFailed = localized("chat.trainingLoadFailed")
  static let trainingShareFailed = localized("chat.trainingShareFailed")
  static let videoFailed = localized("chat.videoFailed")
  static let videoReady = localized("chat.videoReady")
  static let videoUnavailable = localized("chat.videoUnavailable")
  static let videoUploading = localized("chat.videoUploading")
  static let weightRepsMetric = localized("chat.weightRepsMetric")
  // Stable repository sentinel; rendering replaces it with the localized `image` label.
  static let imageSourceMarker = "[\u{56FE}\u{7247}]"
  static let justNow = localized("chat.relative.justNow")
  static let minuteAgo = localized("chat.relative.minuteAgo")
  static let hourAgo = localized("chat.relative.hourAgo")
  static let dayAgo = localized("chat.relative.dayAgo")
  static let monthAgo = localized("chat.relative.monthAgo")
  static let yearAgo = localized("chat.relative.yearAgo")
  static let demoFirstStudent = localized("chat.demo.firstStudent")
  static let demoSecondStudent = localized("chat.demo.secondStudent")
  static let demoCoach = localized("chat.demo.coach")
  static let demoCoachMessage = localized("chat.demo.coachMessage")
  static let demoStudentReply = localized("chat.demo.studentReply")
  static let demoStudentMessage = localized("chat.demo.studentMessage")

  static func setReferenceLoggedTag(locale: Locale = .current) -> String {
    localized("chat.setReference.loggedTag", locale: locale)
  }

  static func setReferencePlannedTag(locale: Locale = .current) -> String {
    localized("chat.setReference.plannedTag", locale: locale)
  }

  static func setReferencePlannedMarker(locale: Locale = .current) -> String {
    localized("chat.setReference.plannedMarker", locale: locale)
  }

  static func setPosition(_ setNumber: Int, locale: Locale = .current) -> String {
    let formattedSetNumber = String(setNumber)
    return String(
      localized: "chat.setPosition \(formattedSetNumber)",
      bundle: .module,
      locale: locale
    )
  }

  static func setPosition(
    _ setNumber: Int,
    total: Int,
    locale: Locale = .current
  ) -> String {
    let formattedSetNumber = String(setNumber)
    let formattedTotal = String(total)
    return String(
      localized: "chat.setPosition \(formattedSetNumber) of \(formattedTotal)",
      bundle: .module,
      locale: locale
    )
  }

  static func minutesAgo(_ count: Int) -> String {
    if count == 1 { return minuteAgo }
    let formattedCount = String(count)
    return String(
      localized: "chat.relative.minutesAgo \(formattedCount)",
      bundle: .module
    )
  }

  static func hoursAgo(_ count: Int) -> String {
    if count == 1 { return hourAgo }
    let formattedCount = String(count)
    return String(
      localized: "chat.relative.hoursAgo \(formattedCount)",
      bundle: .module
    )
  }

  static func daysAgo(_ count: Int) -> String {
    if count == 1 { return dayAgo }
    let formattedCount = String(count)
    return String(
      localized: "chat.relative.daysAgo \(formattedCount)",
      bundle: .module
    )
  }

  static func monthsAgo(_ count: Int) -> String {
    if count == 1 { return monthAgo }
    let formattedCount = String(count)
    return String(
      localized: "chat.relative.monthsAgo \(formattedCount)",
      bundle: .module
    )
  }

  static func yearsAgo(_ count: Int) -> String {
    if count == 1 { return yearAgo }
    let formattedCount = String(count)
    return String(
      localized: "chat.relative.yearsAgo \(formattedCount)",
      bundle: .module
    )
  }

  static func videoMarkers(_ count: Int) -> String {
    localized("chat.videoMarkers").replacing("{count}", with: count.formatted())
  }

  static func videoBadgeCoach(_ coachName: String, locale: Locale = .current) -> String {
    String(
      localized: "chat.videoBadge.coach \(coachName)",
      bundle: .module,
      locale: locale
    )
  }

  static func seekToVideoMarker(_ time: String) -> String {
    localized("chat.seekToVideoMarker").replacing("{time}", with: time)
  }

  private static func localized(
    _ key: String.LocalizationValue,
    locale: Locale = .current
  ) -> String {
    String(localized: key, bundle: .module, locale: locale)
  }
}
