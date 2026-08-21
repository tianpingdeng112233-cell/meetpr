import Foundation

// The generated key namespace intentionally keeps the module's catalog behind
// one thin, typed localization boundary.
// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
enum StudentStrings {
  static let notifications = localized("student.notifications")
  static let notificationsUnread = localized("student.notificationsUnread")
  static let coachMessages = localized("student.coachMessages")
  static let myCoach = localized("student.myCoach")
  static let startCoachConversation = localized("student.startCoachConversation")
  static let unreadSuffix = localized("student.unreadSuffix")
  static let filterTitle = localized("student.filter.title")
  static let filterAllExercises = localized("student.filter.allExercises")
  static let filterSearchPlaceholder = localized("student.filter.searchPlaceholder")
  static let filterClearSearch = localized("student.filter.clearSearch")
  static let acknowledge = localized("student.acknowledge")
  static let askCoach = localized("student.askCoach")
  static let trainingShareConversationFailed = localized(
    "student.trainingShareConversationFailed"
  )
  static let trainingShareFailed = localized("student.trainingShareFailed")

  static func filterNoMatch(_ query: String) -> String {
    String(localized: "student.filter.noMatch \(query)", bundle: .module)
  }

  static func filterAccessibilityLabel(_ selection: String) -> String {
    String(localized: "student.filter.accessibilityLabel \(selection)", bundle: .module)
  }

  // swiftlint:disable:next type_body_length
  struct Key {
    fileprivate let value: String.LocalizationValue
    fileprivate let oneValue: String.LocalizationValue?
    fileprivate let countIndex: Int

    fileprivate init(
      _ value: String.LocalizationValue,
      one oneValue: String.LocalizationValue? = nil,
      countIndex: Int = 0
    ) {
      self.value = value
      self.oneValue = oneValue
      self.countIndex = countIndex
    }

    static let accountSecuritySheets001 = Key("student.accountSecuritySheets.copy001")
    static let accountSecuritySheets002 = Key("student.accountSecuritySheets.copy002")
    static let accountSecuritySheets003 = Key("student.accountSecuritySheets.copy003")
    static let accountSecuritySheets004 = Key("student.accountSecuritySheets.copy004")
    static let accountSecuritySheets005 = Key("student.accountSecuritySheets.copy005")
    static let accountSecuritySheets006 = Key("student.accountSecuritySheets.copy006")
    static let accountSecuritySheets007 = Key("student.accountSecuritySheets.copy007")
    static let accountSecuritySheets008 = Key("student.accountSecuritySheets.copy008")
    static let accountSecuritySheets009 = Key("student.accountSecuritySheets.copy009")
    static let accountSecuritySheets010 = Key("student.accountSecuritySheets.copy010")
    static let accountSecuritySheets011 = Key("student.accountSecuritySheets.copy011")
    static let accountSecuritySheets012 = Key("student.accountSecuritySheets.copy012")
    static let accountSecuritySheets013 = Key("student.accountSecuritySheets.copy013")
    static let accountSecuritySheets014 = Key("student.accountSecuritySheets.copy014")
    static let accountSecuritySheets015 = Key("student.accountSecuritySheets.copy015")
    static let accountSecuritySheets016 = Key("student.accountSecuritySheets.copy016")
    static let accountSecuritySheets017 = Key("student.accountSecuritySheets.copy017")
    static let accountSecuritySheets018 = Key("student.accountSecuritySheets.copy018")
    static let accountSecuritySheets019 = Key("student.accountSecuritySheets.copy019")
    static let accountSecurityViewModels001 = Key("student.accountSecurityViewModels.copy001")
    static let accountSecurityViewModels002 = Key("student.accountSecurityViewModels.copy002")
    static let accountSecurityViewModels003 = Key("student.accountSecurityViewModels.copy003")
    static let accountSecurityViewModels004 = Key("student.accountSecurityViewModels.copy004")
    static let accountSecurityViewModels005 = Key("student.accountSecurityViewModels.copy005")
    static let accountSecurityViewModels006 = Key("student.accountSecurityViewModels.copy006")
    static let appearancePreferenceRow001 = Key("student.appearancePreferenceRow.copy001")
    static let appearancePreferenceRow002 = Key("student.appearancePreferenceRow.copy002")
    static let bindEnterCodeSubviews001 = Key("student.bindEnterCodeSubviews.copy001")
    static let bindEnterCodeSubviews002 = Key("student.bindEnterCodeSubviews.copy002")
    static let bindEnterCodeSubviews003 = Key("student.bindEnterCodeSubviews.copy003")
    static let bindEnterCodeSubviews004 = Key("student.bindEnterCodeSubviews.copy004")
    static let bindEnterCodeSubviews005 = Key("student.bindEnterCodeSubviews.copy005")
    static let bindEnterCodeSubviews006 = Key("student.bindEnterCodeSubviews.copy006")
    static let bindGateView001 = Key("student.bindGateView.copy001")
    static let bindGateView002 = Key("student.bindGateView.copy002")
    static let bindGateView003 = Key("student.bindGateView.copy003")
    static let bindGateView004 = Key("student.bindGateView.copy004")
    static let bindGateView005 = Key("student.bindGateView.copy005")
    static let bindGateView006 = Key("student.bindGateView.copy006")
    static let bindGateView007 = Key("student.bindGateView.copy007")
    static let bindGateViewModel001 = Key("student.bindGateViewModel.copy001")
    static let bindGateViewModel002 = Key("student.bindGateViewModel.copy002")
    static let bindGateViewModel003 = Key("student.bindGateViewModel.copy003")
    static let bindGateViewModel004 = Key("student.bindGateViewModel.copy004")
    static let cameraRecorderComponents001 = Key("student.cameraRecorderComponents.copy001")
    static let cameraRecorderComponents002 = Key(
      "student.cameraRecorderComponents.copy002",
      one: "student.cameraRecorderComponents.copy002.one"
    )
    static let cameraRecorderComponents003 = Key("student.cameraRecorderComponents.copy003")
    static let cameraRecorderComponents004 = Key("student.cameraRecorderComponents.copy004")
    static let cameraRecorderComponents005 = Key("student.cameraRecorderComponents.copy005")
    static let cameraRecorderComponents006 = Key("student.cameraRecorderComponents.copy006")
    static let cameraRecorderComponents007 = Key("student.cameraRecorderComponents.copy007")
    static let cameraRecorderComponents008 = Key("student.cameraRecorderComponents.copy008")
    static let cameraRecorderComponents009 = Key("student.cameraRecorderComponents.copy009")
    static let cameraRecorderComponents010 = Key("student.cameraRecorderComponents.copy010")
    static let cameraRecorderComponents011 = Key("student.cameraRecorderComponents.copy011")
    static let cameraRecorderView001 = Key("student.cameraRecorderView.copy001")
    static let cameraRecorderView002 = Key("student.cameraRecorderView.copy002")
    static let cameraRecorderView003 = Key("student.cameraRecorderView.copy003")
    static let cameraRecorderView004 = Key("student.cameraRecorderView.copy004")
    static let cameraRecorderView005 = Key("student.cameraRecorderView.copy005")
    static let cameraRecorderView006 = Key("student.cameraRecorderView.copy006")
    static let cameraRecorderView007 = Key("student.cameraRecorderView.copy007")
    static let cameraRecorderView008 = Key("student.cameraRecorderView.copy008")
    static let cameraRecorderView009 = Key("student.cameraRecorderView.copy009")
    static let cameraRecorderView010 = Key("student.cameraRecorderView.copy010")
    static let cameraRecorderView011 = Key("student.cameraRecorderView.copy011")
    static let cameraRecorderView012 = Key("student.cameraRecorderView.copy012")
    static let cameraRecorderView013 = Key("student.cameraRecorderView.copy013")
    static let coachNoteDisplay001 = Key("student.coachNoteDisplay.copy001")
    static let coachNoteDisplay002 = Key("student.coachNoteDisplay.copy002")
    static let dashboardE1Rmrail001 = Key("student.dashboardE1Rmrail.copy001")
    static let dashboardE1Rmrail002 = Key("student.dashboardE1Rmrail.copy002")
    static let dashboardE1Rmrail003 = Key(
      "student.dashboardE1Rmrail.copy003",
      one: "student.dashboardE1Rmrail.copy003.one"
    )
    static let dashboardE1Rmrail004 = Key("student.dashboardE1Rmrail.copy004")
    static let dashboardE1RmtrendViewModel001 = Key("student.dashboardE1RmtrendViewModel.copy001")
    static let dashboardE1RmtrendViewModel002 = Key("student.dashboardE1RmtrendViewModel.copy002")
    static let dashboardE1RmtrendViewModel003 = Key("student.dashboardE1RmtrendViewModel.copy003")
    static let dashboardEmptyStatePresentation001 = Key(
      "student.dashboardEmptyStatePresentation.copy001")
    static let dashboardEmptyStatePresentation002 = Key(
      "student.dashboardEmptyStatePresentation.copy002")
    static let dashboardEmptyStatePresentation003 = Key(
      "student.dashboardEmptyStatePresentation.copy003")
    static let dashboardEmptyStatePresentation004 = Key(
      "student.dashboardEmptyStatePresentation.copy004")
    static let dashboardEmptyStatePresentation005 = Key(
      "student.dashboardEmptyStatePresentation.copy005")
    static let dashboardFeedbackCard001 = Key("student.dashboardFeedbackCard.copy001")
    static let dashboardFeedbackCard002 = Key("student.dashboardFeedbackCard.copy002")
    static let dashboardFeedbackCard003 = Key("student.dashboardFeedbackCard.copy003")
    static let dashboardFeedbackCard004 = Key("student.dashboardFeedbackCard.copy004")
    static let dashboardFeedbackCard005 = Key("student.dashboardFeedbackCard.copy005")
    static let dashboardFeedbackCard006 = Key("student.dashboardFeedbackCard.copy006")
    static let dashboardFeedbackEmptyCards001 = Key("student.dashboardFeedbackEmptyCards.copy001")
    static let dashboardFeedbackEmptyCards002 = Key("student.dashboardFeedbackEmptyCards.copy002")
    static let dashboardFeedbackEmptyCards003 = Key("student.dashboardFeedbackEmptyCards.copy003")
    static let dashboardFeedbackEmptyCards004 = Key("student.dashboardFeedbackEmptyCards.copy004")
    static let dashboardFeedbackEmptyCards005 = Key("student.dashboardFeedbackEmptyCards.copy005")
    static let dashboardFeedbackEmptyCards006 = Key("student.dashboardFeedbackEmptyCards.copy006")
    static let dashboardFeedbackEmptyCards007 = Key("student.dashboardFeedbackEmptyCards.copy007")
    static let dashboardFeedbackText001 = Key("student.dashboardFeedbackText.copy001")
    static let dashboardFeedbackText002 = Key("student.dashboardFeedbackText.copy002")
    static let dashboardFeedbackText003 = Key("student.dashboardFeedbackText.copy003")
    static let dashboardFeedbackText004 = Key("student.dashboardFeedbackText.copy004")
    static let dashboardHeader001 = Key("student.dashboardHeader.copy001")
    static let dashboardPlanWaitingState001 = Key("student.dashboardPlanWaitingState.copy001")
    static let dashboardPlanWaitingState002 = Key("student.dashboardPlanWaitingState.copy002")
    static let dashboardPlanWaitingState003 = Key("student.dashboardPlanWaitingState.copy003")
    static let dashboardPlanWaitingState004 = Key("student.dashboardPlanWaitingState.copy004")
    static let dashboardPlanWaitingState005 = Key("student.dashboardPlanWaitingState.copy005")
    static let dashboardPlanWaitingState006 = Key("student.dashboardPlanWaitingState.copy006")
    static let dashboardPlanWaitingState007 = Key("student.dashboardPlanWaitingState.copy007")
    static let dashboardPlanWaitingState008 = Key("student.dashboardPlanWaitingState.copy008")
    static let dashboardPlanWaitingState009 = Key("student.dashboardPlanWaitingState.copy009")
    static let dashboardPrimaryAction001 = Key("student.dashboardPrimaryAction.copy001")
    static let dashboardPrimaryAction002 = Key("student.dashboardPrimaryAction.copy002")
    static let dashboardPrimaryAction003 = Key("student.dashboardPrimaryAction.copy003")
    static let dashboardPrimaryAction004 = Key("student.dashboardPrimaryAction.copy004")
    static let dashboardPrimaryAction005 = Key("student.dashboardPrimaryAction.copy005")
    static let dashboardPrimaryAction006 = Key(
      "student.dashboardPrimaryAction.copy006",
      one: "student.dashboardPrimaryAction.copy006.one"
    )
    static let dashboardPrimaryAction007 = Key(
      "student.dashboardPrimaryAction.copy007",
      one: "student.dashboardPrimaryAction.copy007.one",
      countIndex: 1
    )
    static let dashboardPrimaryAction008 = Key("student.dashboardPrimaryAction.copy008")
    static let dashboardPrimaryAction009 = Key("student.dashboardPrimaryAction.copy009")
    static let dashboardProfileMetricsView001 = Key("student.dashboardProfileMetricsView.copy001")
    static let dashboardProfileMetricsView002 = Key("student.dashboardProfileMetricsView.copy002")
    static let dashboardProfileMetricsView003 = Key("student.dashboardProfileMetricsView.copy003")
    static let dashboardProfileMetricsView004 = Key("student.dashboardProfileMetricsView.copy004")
    static let dashboardProfileMetricsView005 = Key(
      "student.dashboardProfileMetricsView.copy005",
      one: "student.dashboardProfileMetricsView.copy005.one"
    )
    static let dashboardProfileMetricsView006 = Key("student.dashboardProfileMetricsView.copy006")
    static let dashboardProfileMetricsView007 = Key("student.dashboardProfileMetricsView.copy007")
    static let dashboardProfileMetricsView008 = Key("student.dashboardProfileMetricsView.copy008")
    static let dashboardTodayPresentation001 = Key("student.dashboardTodayPresentation.copy001")
    static let dashboardTodayPresentation002 = Key("student.dashboardTodayPresentation.copy002")
    static let dashboardTodayPresentation003 = Key("student.dashboardTodayPresentation.copy003")
    static let dashboardTodayPresentation004 = Key("student.dashboardTodayPresentation.copy004")
    static let dashboardTodayPresentation005 = Key("student.dashboardTodayPresentation.copy005")
    static let dashboardTodayPresentation006 = Key("student.dashboardTodayPresentation.copy006")
    static let dashboardTodayPresentation007 = Key("student.dashboardTodayPresentation.copy007")
    static let dashboardTodayPresentation008 = Key("student.dashboardTodayPresentation.copy008")
    static let dashboardTodayPresentation009 = Key("student.dashboardTodayPresentation.copy009")
    static let dashboardTodayPresentation010 = Key("student.dashboardTodayPresentation.copy010")
    static let dashboardTodayPresentation011 = Key("student.dashboardTodayPresentation.copy011")
    static let dashboardTodayPresentation012 = Key("student.dashboardTodayPresentation.copy012")
    static let dashboardTodayPresentation013 = Key("student.dashboardTodayPresentation.copy013")
    static let dashboardTodayPresentation014 = Key("student.dashboardTodayPresentation.copy014")
    static let dashboardTodayPresentation015 = Key("student.dashboardTodayPresentation.copy015")
    static let dashboardTodayPresentation016 = Key("student.dashboardTodayPresentation.copy016")
    static let dashboardTodayPresentation017 = Key("student.dashboardTodayPresentation.copy017")
    static let dashboardTodayScreen001 = Key("student.dashboardTodayScreen.copy001")
    static let dashboardTodayScreen002 = Key("student.dashboardTodayScreen.copy002")
    static let dashboardTodayScreen003 = Key("student.dashboardTodayScreen.copy003")
    static let dashboardV3Previews001 = Key("student.dashboardV3Previews.copy001")
    static let dashboardV3Previews002 = Key("student.dashboardV3Previews.copy002")
    static let dashboardV3Previews003 = Key("student.dashboardV3Previews.copy003")
    static let dashboardV3Previews004 = Key("student.dashboardV3Previews.copy004")
    static let dashboardV3Previews005 = Key("student.dashboardV3Previews.copy005")
    static let dashboardV3Previews006 = Key("student.dashboardV3Previews.copy006")
    static let dashboardV3Previews007 = Key("student.dashboardV3Previews.copy007")
    static let dashboardV3Previews008 = Key("student.dashboardV3Previews.copy008")
    static let dashboardView001 = Key("student.dashboardView.copy001")
    static let dashboardView002 = Key("student.dashboardView.copy002")
    static let dashboardView003 = Key("student.dashboardView.copy003")
    static let dashboardView004 = Key("student.dashboardView.copy004")
    static let dashboardWeekCalendar001 = Key("student.dashboardWeekCalendar.copy001")
    static let dashboardWeekCalendar002 = Key("student.dashboardWeekCalendar.copy002")
    static let dashboardWeekCalendar003 = Key("student.dashboardWeekCalendar.copy003")
    static let dashboardWeekCalendar004 = Key("student.dashboardWeekCalendar.copy004")
    static let dashboardWeekCalendar005 = Key("student.dashboardWeekCalendar.copy005")
    static let dashboardWeekCalendar006 = Key("student.dashboardWeekCalendar.copy006")
    static let dashboardWeekCalendar007 = Key("student.dashboardWeekCalendar.copy007")
    static let dashboardWeekCalendar008 = Key("student.dashboardWeekCalendar.copy008")
    static let dashboardWeekCalendar009 = Key("student.dashboardWeekCalendar.copy009")
    static let dashboardWeekCalendar010 = Key("student.dashboardWeekCalendar.copy010")
    static let dashboardWeekCalendar011 = Key("student.dashboardWeekCalendar.copy011")
    static let dashboardWeekCalendar012 = Key("student.dashboardWeekCalendar.copy012")
    static let dashboardWeekCalendar013 = Key("student.dashboardWeekCalendar.copy013")
    static let dashboardWeekCalendar014 = Key("student.dashboardWeekCalendar.copy014")
    static let dayCompletionBanner001 = Key(
      "student.dayCompletionBanner.copy001",
      one: "student.dayCompletionBanner.copy001.one"
    )
    static let dayCompletionBanner002 = Key("student.dayCompletionBanner.copy002")
    static let dayCompletionBanner003 = Key(
      "student.dayCompletionBanner.copy003",
      one: "student.dayCompletionBanner.copy003.one"
    )
    static let dayDetailView001 = Key("student.dayDetailView.copy001")
    static let dayDetailView002 = Key("student.dayDetailView.copy002")
    static let dayDetailView003 = Key("student.dayDetailView.copy003")
    static let e1RmcompetitionLiftGate001 = Key("student.e1RmcompetitionLiftGate.copy001")
    static let e1RmcompetitionLiftGate002 = Key("student.e1RmcompetitionLiftGate.copy002")
    static let e1RmcompetitionLiftGate003 = Key("student.e1RmcompetitionLiftGate.copy003")
    static let e1RmcompetitionLiftGate004 = Key("student.e1RmcompetitionLiftGate.copy004")
    static let enterCodeView001 = Key("student.enterCodeView.copy001")
    static let enterCodeView002 = Key("student.enterCodeView.copy002")
    static let enterCodeView003 = Key("student.enterCodeView.copy003")
    static let enterCodeView004 = Key("student.enterCodeView.copy004")
    static let enterCodeView005 = Key("student.enterCodeView.copy005")
    static let enterCodeViewModel001 = Key("student.enterCodeViewModel.copy001")
    static let enterCodeViewModel002 = Key("student.enterCodeViewModel.copy002")
    static let equipmentCatalog001 = Key("student.equipmentCatalog.copy001")
    static let equipmentCatalog002 = Key("student.equipmentCatalog.copy002")
    static let equipmentCatalog003 = Key("student.equipmentCatalog.copy003")
    static let equipmentCatalog004 = Key("student.equipmentCatalog.copy004")
    static let equipmentCatalog005 = Key("student.equipmentCatalog.copy005")
    static let equipmentCatalog006 = Key("student.equipmentCatalog.copy006")
    static let equipmentCatalog007 = Key("student.equipmentCatalog.copy007")
    static let equipmentCatalog008 = Key("student.equipmentCatalog.copy008")
    static let equipmentCatalog009 = Key("student.equipmentCatalog.copy009")
    static let equipmentCatalog010 = Key("student.equipmentCatalog.copy010")
    static let equipmentCatalog011 = Key("student.equipmentCatalog.copy011")
    static let equipmentCatalog012 = Key("student.equipmentCatalog.copy012")
    static let equipmentCatalog013 = Key("student.equipmentCatalog.copy013")
    static let equipmentCatalog014 = Key("student.equipmentCatalog.copy014")
    static let equipmentCatalog015 = Key("student.equipmentCatalog.copy015")
    static let equipmentCatalog016 = Key("student.equipmentCatalog.copy016")
    static let equipmentCatalog017 = Key("student.equipmentCatalog.copy017")
    static let equipmentCatalog018 = Key("student.equipmentCatalog.copy018")
    static let equipmentCatalog019 = Key("student.equipmentCatalog.copy019")
    static let equipmentCatalog020 = Key("student.equipmentCatalog.copy020")
    static let equipmentCatalog021 = Key("student.equipmentCatalog.copy021")
    static let equipmentCatalog022 = Key("student.equipmentCatalog.copy022")
    static let equipmentCatalog023 = Key("student.equipmentCatalog.copy023")
    static let equipmentCatalog024 = Key("student.equipmentCatalog.copy024")
    static let equipmentCatalog025 = Key("student.equipmentCatalog.copy025")
    static let equipmentCatalog026 = Key("student.equipmentCatalog.copy026")
    static let equipmentCatalog027 = Key("student.equipmentCatalog.copy027")
    static let equipmentCatalog028 = Key("student.equipmentCatalog.copy028")
    static let evaluationCompletedCard001 = Key("student.evaluationCompletedCard.copy001")
    static let evaluationCompletedCard002 = Key("student.evaluationCompletedCard.copy002")
    static let evaluationCompletedCard003 = Key("student.evaluationCompletedCard.copy003")
    static let evaluationPeriodView001 = Key("student.evaluationPeriodView.copy001")
    static let evaluationPeriodView002 = Key("student.evaluationPeriodView.copy002")
    static let evaluationPeriodView003 = Key("student.evaluationPeriodView.copy003")
    static let evaluationPeriodView004 = Key("student.evaluationPeriodView.copy004")
    static let evaluationPeriodView005 = Key("student.evaluationPeriodView.copy005")
    static let evaluationPeriodView006 = Key("student.evaluationPeriodView.copy006")
    static let evaluationPeriodView007 = Key("student.evaluationPeriodView.copy007")
    static let evaluationPeriodView008 = Key("student.evaluationPeriodView.copy008")
    static let evaluationPeriodView009 = Key("student.evaluationPeriodView.copy009")
    static let evaluationPeriodView010 = Key("student.evaluationPeriodView.copy010")
    static let evaluationPeriodView011 = Key("student.evaluationPeriodView.copy011")
    static let evaluationPeriodView012 = Key("student.evaluationPeriodView.copy012")
    static let evaluationPeriodView013 = Key("student.evaluationPeriodView.copy013")
    static let evaluationPeriodViewModel001 = Key("student.evaluationPeriodViewModel.copy001")
    static let evaluationPeriodViewModel002 = Key("student.evaluationPeriodViewModel.copy002")
    static let evaluationSummaryView001 = Key("student.evaluationSummaryView.copy001")
    static let evaluationSummaryView002 = Key("student.evaluationSummaryView.copy002")
    static let evaluationSummaryView003 = Key("student.evaluationSummaryView.copy003")
    static let evaluationSummaryView004 = Key("student.evaluationSummaryView.copy004")
    static let evaluationSummaryView005 = Key("student.evaluationSummaryView.copy005")
    static let exportDataSheet001 = Key("student.exportDataSheet.copy001")
    static let exportDataSheet002 = Key("student.exportDataSheet.copy002")
    static let exportDataSheet003 = Key("student.exportDataSheet.copy003")
    static let exportDataSheet004 = Key("student.exportDataSheet.copy004")
    static let exportDataSheet005 = Key("student.exportDataSheet.copy005")
    static let exportDataSheet006 = Key("student.exportDataSheet.copy006")
    static let exportDataSheet007 = Key("student.exportDataSheet.copy007")
    static let feedbackDetailView001 = Key("student.feedbackDetailView.copy001")
    static let feedbackDetailView002 = Key("student.feedbackDetailView.copy002")
    static let feedbackDetailView003 = Key("student.feedbackDetailView.copy003")
    static let feedbackDetailView004 = Key("student.feedbackDetailView.copy004")
    static let feedbackDetailView005 = Key("student.feedbackDetailView.copy005")
    static let feedbackDetailView006 = Key("student.feedbackDetailView.copy006")
    static let feedbackDetailView007 = Key("student.feedbackDetailView.copy007")
    static let feedbackDetailView008 = Key("student.feedbackDetailView.copy008")
    static let feedbackDetailView009 = Key("student.feedbackDetailView.copy009")
    static let feedbackInboxView001 = Key("student.feedbackInboxView.copy001")
    static let feedbackInboxView002 = Key("student.feedbackInboxView.copy002")
    static let feedbackInboxView003 = Key("student.feedbackInboxView.copy003")
    static let feedbackInboxView004 = Key("student.feedbackInboxView.copy004")
    static let feedbackInboxView005 = Key("student.feedbackInboxView.copy005")
    static let feedbackInboxView006 = Key("student.feedbackInboxView.copy006")
    static let feedbackInboxView007 = Key("student.feedbackInboxView.copy007")
    static let feedbackInboxView008 = Key("student.feedbackInboxView.copy008")
    static let feedbackInboxView009 = Key("student.feedbackInboxView.copy009")
    static let feedbackInboxView010 = Key("student.feedbackInboxView.copy010")
    static let feedbackInboxView011 = Key("student.feedbackInboxView.copy011")
    static let feedbackVideoPresentation001 = Key("student.feedbackVideoPresentation.copy001")
    static let feedbackVideoPresentation002 = Key(
      "student.feedbackVideoPresentation.copy002",
      one: "student.feedbackVideoPresentation.copy002.one",
      countIndex: 1
    )
    static let feedbackVideoPresentation003 = Key(
      "student.feedbackVideoPresentation.copy003",
      one: "student.feedbackVideoPresentation.copy003.one"
    )
    static let growthCurveView001 = Key("student.growthCurveView.copy001")
    static let growthCurveView002 = Key("student.growthCurveView.copy002")
    static let growthCurveView003 = Key("student.growthCurveView.copy003")
    static let growthCurveView004 = Key("student.growthCurveView.copy004")
    static let growthCurveView005 = Key("student.growthCurveView.copy005")
    static let growthCurveView006 = Key("student.growthCurveView.copy006")
    static let growthCurveView007 = Key("student.growthCurveView.copy007")
    static let growthCurveView008 = Key("student.growthCurveView.copy008")
    static let growthCurveView009 = Key("student.growthCurveView.copy009")
    static let growthCurveView010 = Key("student.growthCurveView.copy010")
    static let growthCurveViewModel001 = Key("student.growthCurveViewModel.copy001")
    static let growthCurveViewModel002 = Key("student.growthCurveViewModel.copy002")
    static let growthCurveViewModel003 = Key("student.growthCurveViewModel.copy003")
    static let growthE1Rmcard001 = Key("student.growthE1Rmcard.copy001")
    static let growthE1Rmcard002 = Key("student.growthE1Rmcard.copy002")
    static let growthE1Rmcard003 = Key("student.growthE1Rmcard.copy003")
    static let growthE1Rmcard004 = Key("student.growthE1Rmcard.copy004")
    static let growthE1Rmcard005 = Key(
      "student.growthE1Rmcard.copy005",
      one: "student.growthE1Rmcard.copy005.one",
      countIndex: 1
    )
    static let growthE1Rmcard006 = Key("student.growthE1Rmcard.copy006")
    static let growthE1Rmcard007 = Key("student.growthE1Rmcard.copy007")
    static let growthEmptyStates001 = Key("student.growthEmptyStates.copy001")
    static let growthEmptyStates002 = Key("student.growthEmptyStates.copy002")
    static let growthEmptyStates003 = Key("student.growthEmptyStates.copy003")
    static let growthEmptyStates004 = Key("student.growthEmptyStates.copy004")
    static let growthEmptyStates005 = Key(
      "student.growthEmptyStates.copy005",
      one: "student.growthEmptyStates.copy005.one"
    )
    static let growthEmptyStates006 = Key("student.growthEmptyStates.copy006")
    static let growthEmptyStates007 = Key("student.growthEmptyStates.copy007")
    static let growthEmptyStates008 = Key("student.growthEmptyStates.copy008")
    static let growthEmptyStates009 = Key("student.growthEmptyStates.copy009")
    static let growthProfileV3Previews001 = Key("student.growthProfileV3Previews.copy001")
    static let growthProfileV3Previews002 = Key("student.growthProfileV3Previews.copy002")
    static let growthProfileV3Previews003 = Key("student.growthProfileV3Previews.copy003")
    static let growthProfileV3Previews004 = Key("student.growthProfileV3Previews.copy004")
    static let growthProfileV3Previews005 = Key("student.growthProfileV3Previews.copy005")
    static let growthProfileV3Previews006 = Key("student.growthProfileV3Previews.copy006")
    static let growthScreenPresentation001 = Key("student.growthScreenPresentation.copy001")
    static let growthScreenPresentation002 = Key("student.growthScreenPresentation.copy002")
    static let growthScreenPresentation003 = Key("student.growthScreenPresentation.copy003")
    static let growthScreenPresentation004 = Key("student.growthScreenPresentation.copy004")
    static let historyEntriesView001 = Key("student.historyEntriesView.copy001")
    static let historyEntriesView002 = Key("student.historyEntriesView.copy002")
    static let historyEntriesView003 = Key("student.historyEntriesView.copy003")
    static let historyEntriesView004 = Key(
      "student.historyEntriesView.copy004",
      one: "student.historyEntriesView.copy004.one",
      countIndex: 1
    )
    static let importedHistoryReviewAlert001 = Key("student.importedHistoryReviewAlert.copy001")
    static let importedHistoryReviewAlert002 = Key("student.importedHistoryReviewAlert.copy002")
    static let importedHistoryReviewAlert003 = Key("student.importedHistoryReviewAlert.copy003")
    static let importedHistoryReviewAlert004 = Key("student.importedHistoryReviewAlert.copy004")
    static let importedHistoryReviewAlert005 = Key("student.importedHistoryReviewAlert.copy005")
    static let importedHistoryReviewAlert006 = Key("student.importedHistoryReviewAlert.copy006")
    static let importedHistoryReviewAlert007 = Key("student.importedHistoryReviewAlert.copy007")
    static let inviteCodeEntry001 = Key("student.inviteCodeEntry.copy001")
    static let inviteCodeEntry002 = Key("student.inviteCodeEntry.copy002")
    static let inviteCodeEntry003 = Key("student.inviteCodeEntry.copy003")
    static let inviteCodeEntry004 = Key("student.inviteCodeEntry.copy004")
    static let inviteCodeEntry005 = Key("student.inviteCodeEntry.copy005")
    static let inviteCodeEntry006 = Key("student.inviteCodeEntry.copy006")
    static let mainLiftExerciseFamilyResolver001 = Key(
      "student.mainLiftExerciseFamilyResolver.copy001")
    static let mainLiftExerciseFamilyResolver002 = Key(
      "student.mainLiftExerciseFamilyResolver.copy002")
    static let mainLiftExerciseFamilyResolver003 = Key(
      "student.mainLiftExerciseFamilyResolver.copy003")
    static let myProfileV3Presentation001 = Key("student.myProfileV3Presentation.copy001")
    static let myProfileV3Presentation002 = Key("student.myProfileV3Presentation.copy002")
    static let myProfileV3Presentation003 = Key("student.myProfileV3Presentation.copy003")
    static let myProfileV3Presentation004 = Key("student.myProfileV3Presentation.copy004")
    static let myProfileV3Presentation005 = Key("student.myProfileV3Presentation.copy005")
    static let myProfileV3Presentation006 = Key("student.myProfileV3Presentation.copy006")
    static let myProfileV3Presentation007 = Key("student.myProfileV3Presentation.copy007")
    static let myProfileV3Presentation008 = Key("student.myProfileV3Presentation.copy008")
    static let myProfileV3Presentation009 = Key(
      "student.myProfileV3Presentation.copy009",
      one: "student.myProfileV3Presentation.copy009.one"
    )
    static let myProfileV3Presentation010 = Key("student.myProfileV3Presentation.copy010")
    static let myProfileView001 = Key("student.myProfileView.copy001")
    static let myProfileView002 = Key("student.myProfileView.copy002")
    static let myProfileView003 = Key("student.myProfileView.copy003")
    static let myProfileView004 = Key("student.myProfileView.copy004")
    static let myProfileView005 = Key("student.myProfileView.copy005")
    static let myProfileView006 = Key("student.myProfileView.copy006")
    static let myProfileView007 = Key("student.myProfileView.copy007")
    static let myProfileView008 = Key("student.myProfileView.copy008")
    static let myProfileView009 = Key("student.myProfileView.copy009")
    static let myProfileView010 = Key("student.myProfileView.copy010")
    static let myProfileView011 = Key("student.myProfileView.copy011")
    static let myProfileView012 = Key("student.myProfileView.copy012")
    static let myProfileView013 = Key("student.myProfileView.copy013")
    static let myProfileView014 = Key("student.myProfileView.copy014")
    static let myProfileView015 = Key("student.myProfileView.copy015")
    static let myProfileView016 = Key("student.myProfileView.copy016")
    static let myProfileView017 = Key("student.myProfileView.copy017")
    static let myProfileView018 = Key("student.myProfileView.copy018")
    static let myProfileView019 = Key("student.myProfileView.copy019")
    static let myProfileView020 = Key("student.myProfileView.copy020")
    static let myProfileView021 = Key("student.myProfileView.copy021")
    static let myProfileView022 = Key("student.myProfileView.copy022")
    static let myProfileView023 = Key("student.myProfileView.copy023")
    static let myProfileView024 = Key("student.myProfileView.copy024")
    static let myProfileViewModel001 = Key("student.myProfileViewModel.copy001")
    static let myProfileViewModel002 = Key("student.myProfileViewModel.copy002")
    static let onboardingFieldComponents001 = Key("student.onboardingFieldComponents.copy001")
    static let onboardingLabels001 = Key("student.onboardingLabels.copy001")
    static let onboardingLabels002 = Key("student.onboardingLabels.copy002")
    static let onboardingLabels003 = Key("student.onboardingLabels.copy003")
    static let onboardingLabels004 = Key("student.onboardingLabels.copy004")
    static let onboardingLabels005 = Key("student.onboardingLabels.copy005")
    static let onboardingLabels006 = Key("student.onboardingLabels.copy006")
    static let onboardingLabels007 = Key("student.onboardingLabels.copy007")
    static let onboardingLabels008 = Key("student.onboardingLabels.copy008")
    static let onboardingLabels009 = Key("student.onboardingLabels.copy009")
    static let onboardingLabels010 = Key("student.onboardingLabels.copy010")
    static let onboardingLabels011 = Key("student.onboardingLabels.copy011")
    static let onboardingLabels012 = Key("student.onboardingLabels.copy012")
    static let onboardingLabels013 = Key("student.onboardingLabels.copy013")
    static let onboardingLabels014 = Key("student.onboardingLabels.copy014")
    static let onboardingLabels015 = Key("student.onboardingLabels.copy015")
    static let onboardingLabels016 = Key("student.onboardingLabels.copy016")
    static let onboardingLabels017 = Key("student.onboardingLabels.copy017")
    static let onboardingLabels018 = Key("student.onboardingLabels.copy018")
    static let onboardingLabels019 = Key("student.onboardingLabels.copy019")
    static let onboardingLabels020 = Key("student.onboardingLabels.copy020")
    static let onboardingLabels021 = Key("student.onboardingLabels.copy021")
    static let onboardingLabels022 = Key("student.onboardingLabels.copy022")
    static let onboardingLabels023 = Key("student.onboardingLabels.copy023")
    static let onboardingLabels024 = Key("student.onboardingLabels.copy024")
    static let onboardingLabels025 = Key("student.onboardingLabels.copy025")
    static let onboardingLabels026 = Key("student.onboardingLabels.copy026")
    static let onboardingLabels027 = Key("student.onboardingLabels.copy027")
    static let onboardingLabels028 = Key("student.onboardingLabels.copy028")
    static let onboardingLabels029 = Key("student.onboardingLabels.copy029")
    static let onboardingLabels030 = Key("student.onboardingLabels.copy030")
    static let onboardingLabels031 = Key("student.onboardingLabels.copy031")
    static let onboardingLabels032 = Key("student.onboardingLabels.copy032")
    static let onboardingLabels033 = Key("student.onboardingLabels.copy033")
    static let onboardingLabels034 = Key("student.onboardingLabels.copy034")
    static let onboardingLabels035 = Key("student.onboardingLabels.copy035")
    static let onboardingLabels036 = Key("student.onboardingLabels.copy036")
    static let onboardingLabels037 = Key("student.onboardingLabels.copy037")
    static let onboardingLabels038 = Key("student.onboardingLabels.copy038")
    static let onboardingLabels039 = Key("student.onboardingLabels.copy039")
    static let onboardingLabels040 = Key("student.onboardingLabels.copy040")
    static let onboardingLabels041 = Key("student.onboardingLabels.copy041")
    static let onboardingLabels042 = Key("student.onboardingLabels.copy042")
    static let onboardingLabels043 = Key("student.onboardingLabels.copy043")
    static let onboardingLabels044 = Key("student.onboardingLabels.copy044")
    static let onboardingLabels045 = Key("student.onboardingLabels.copy045")
    static let onboardingLabels046 = Key("student.onboardingLabels.copy046")
    static let onboardingLabels047 = Key(
      "student.onboardingLabels.copy047",
      one: "student.onboardingLabels.copy047.one"
    )
    static let onboardingLabels048 = Key("student.onboardingLabels.copy048")
    static let onboardingLabels049 = Key("student.onboardingLabels.copy049")
    static let onboardingLabels050 = Key("student.onboardingLabels.copy050")
    static let onboardingLabels051 = Key("student.onboardingLabels.copy051")
    static let onboardingLabels052 = Key("student.onboardingLabels.copy052")
    static let onboardingLabels053 = Key("student.onboardingLabels.copy053")
    static let onboardingLabels054 = Key("student.onboardingLabels.copy054")
    static let onboardingLabels055 = Key("student.onboardingLabels.copy055")
    static let onboardingLabels056 = Key("student.onboardingLabels.copy056")
    static let onboardingLabels057 = Key("student.onboardingLabels.copy057")
    static let onboardingLabels058 = Key("student.onboardingLabels.copy058")
    static let onboardingSummaryFormatter001 = Key("student.onboardingSummaryFormatter.copy001")
    static let onboardingSummaryFormatter002 = Key("student.onboardingSummaryFormatter.copy002")
    static let onboardingSummaryFormatter003 = Key("student.onboardingSummaryFormatter.copy003")
    static let onboardingSummaryFormatter004 = Key("student.onboardingSummaryFormatter.copy004")
    static let onboardingSummaryFormatter005 = Key(
      "student.onboardingSummaryFormatter.copy005",
      one: "student.onboardingSummaryFormatter.copy005.one",
      countIndex: 1
    )
    static let onboardingSummaryFormatter006 = Key("student.onboardingSummaryFormatter.copy006")
    static let onboardingSummaryFormatter007 = Key("student.onboardingSummaryFormatter.copy007")
    static let onboardingSummaryFormatter008 = Key("student.onboardingSummaryFormatter.copy008")
    static let onboardingSummaryFormatter009 = Key("student.onboardingSummaryFormatter.copy009")
    static let onboardingSummaryFormatter010 = Key("student.onboardingSummaryFormatter.copy010")
    static let onboardingSummaryFormatter011 = Key("student.onboardingSummaryFormatter.copy011")
    static let onboardingSummaryFormatter012 = Key("student.onboardingSummaryFormatter.copy012")
    static let onboardingSummaryFormatter013 = Key("student.onboardingSummaryFormatter.copy013")
    static let onboardingSummaryFormatter014 = Key("student.onboardingSummaryFormatter.copy014")
    static let onboardingSummaryFormatter015 = Key("student.onboardingSummaryFormatter.copy015")
    static let onboardingSummaryFormatter016 = Key("student.onboardingSummaryFormatter.copy016")
    static let onboardingSummaryFormatter017 = Key("student.onboardingSummaryFormatter.copy017")
    static let onboardingWizardView001 = Key("student.onboardingWizardView.copy001")
    static let onboardingWizardView002 = Key("student.onboardingWizardView.copy002")
    static let onboardingWizardView003 = Key("student.onboardingWizardView.copy003")
    static let onboardingWizardView004 = Key("student.onboardingWizardView.copy004")
    static let onboardingWizardView005 = Key("student.onboardingWizardView.copy005")
    static let onboardingWizardView006 = Key("student.onboardingWizardView.copy006")
    static let onboardingWizardView007 = Key("student.onboardingWizardView.copy007")
    static let onboardingWizardView008 = Key("student.onboardingWizardView.copy008")
    static let onboardingWizardView009 = Key("student.onboardingWizardView.copy009")
    static let onboardingWizardView010 = Key("student.onboardingWizardView.copy010")
    static let onboardingWizardView011 = Key("student.onboardingWizardView.copy011")
    static let onboardingWizardView012 = Key("student.onboardingWizardView.copy012")
    static let onboardingWizardView013 = Key("student.onboardingWizardView.copy013")
    static let onboardingWizardView014 = Key("student.onboardingWizardView.copy014")
    static let onboardingWizardView015 = Key("student.onboardingWizardView.copy015")
    static let onboardingWizardView016 = Key("student.onboardingWizardView.copy016")
    static let onboardingWizardView017 = Key("student.onboardingWizardView.copy017")
    static let onboardingWizardView018 = Key("student.onboardingWizardView.copy018")
    static let onboardingWizardViewModel001 = Key("student.onboardingWizardViewModel.copy001")
    static let onboardingWizardViewModel002 = Key("student.onboardingWizardViewModel.copy002")
    static let onboardingWizardViewModel003 = Key("student.onboardingWizardViewModel.copy003")
    static let onboardingWizardViewModel004 = Key("student.onboardingWizardViewModel.copy004")
    static let pendingBindView001 = Key("student.pendingBindView.copy001")
    static let pendingBindView002 = Key("student.pendingBindView.copy002")
    static let pendingBindView003 = Key("student.pendingBindView.copy003")
    static let pendingBindView004 = Key("student.pendingBindView.copy004")
    static let pendingBindView005 = Key("student.pendingBindView.copy005")
    static let pendingBindView006 = Key("student.pendingBindView.copy006")
    static let pendingBindView007 = Key("student.pendingBindView.copy007")
    static let pendingBindView008 = Key("student.pendingBindView.copy008")
    static let pendingBindView009 = Key("student.pendingBindView.copy009")
    static let pendingBindView010 = Key("student.pendingBindView.copy010")
    static let pendingBindView011 = Key("student.pendingBindView.copy011")
    static let pendingBindView012 = Key(
      "student.pendingBindView.copy012",
      one: "student.pendingBindView.copy012.one"
    )
    static let pendingBindViewModel001 = Key("student.pendingBindViewModel.copy001")
    static let pendingBindViewModel002 = Key("student.pendingBindViewModel.copy002")
    static let pendingBindViewModel003 = Key("student.pendingBindViewModel.copy003")
    static let pendingBindViewModel004 = Key(
      "student.pendingBindViewModel.copy004",
      one: "student.pendingBindViewModel.copy004.one"
    )
    static let profileCardsSection001 = Key("student.profileCardsSection.copy001")
    static let profileCardsSection002 = Key("student.profileCardsSection.copy002")
    static let profileCardsSection003 = Key("student.profileCardsSection.copy003")
    static let profileCardsSection004 = Key("student.profileCardsSection.copy004")
    static let profileCardsSection005 = Key("student.profileCardsSection.copy005")
    static let profileCardsSection006 = Key("student.profileCardsSection.copy006")
    static let profileCardsSection007 = Key("student.profileCardsSection.copy007")
    static let profileCardsSection008 = Key("student.profileCardsSection.copy008")
    static let profileCardsSection009 = Key("student.profileCardsSection.copy009")
    static let profileCardsSection010 = Key("student.profileCardsSection.copy010")
    static let profileCardsSection011 = Key("student.profileCardsSection.copy011")
    static let profileCardsSection012 = Key("student.profileCardsSection.copy012")
    static let profileCardsSection013 = Key("student.profileCardsSection.copy013")
    static let progressDashboardView001 = Key("student.progressDashboardView.copy001")
    static let progressDashboardView002 = Key("student.progressDashboardView.copy002")
    static let readinessCheckinSheet001 = Key("student.readinessCheckinSheet.copy001")
    static let readinessCheckinSheet002 = Key("student.readinessCheckinSheet.copy002")
    static let readinessCheckinSheet003 = Key("student.readinessCheckinSheet.copy003")
    static let readinessCheckinSheet004 = Key("student.readinessCheckinSheet.copy004")
    static let readinessCheckinSheet005 = Key("student.readinessCheckinSheet.copy005")
    static let readinessCheckinSheet006 = Key("student.readinessCheckinSheet.copy006")
    static let readinessCheckinSheet007 = Key("student.readinessCheckinSheet.copy007")
    static let readinessCheckinSheet008 = Key("student.readinessCheckinSheet.copy008")
    static let readinessCheckinSheet009 = Key("student.readinessCheckinSheet.copy009")
    static let readinessCheckinSheet010 = Key("student.readinessCheckinSheet.copy010")
    static let readinessCheckinSheet011 = Key("student.readinessCheckinSheet.copy011")
    static let readinessCheckinSheet012 = Key("student.readinessCheckinSheet.copy012")
    static let readinessCheckinSheet013 = Key("student.readinessCheckinSheet.copy013")
    static let readinessCheckinSheet014 = Key("student.readinessCheckinSheet.copy014")
    static let readinessCheckinSheet015 = Key("student.readinessCheckinSheet.copy015")
    static let readinessCheckinSheet016 = Key("student.readinessCheckinSheet.copy016")
    static let readinessCheckinSheet017 = Key("student.readinessCheckinSheet.copy017")
    static let readinessCheckinSheet018 = Key("student.readinessCheckinSheet.copy018")
    static let readinessCheckinSheet019 = Key("student.readinessCheckinSheet.copy019")
    static let readinessCheckinSheet020 = Key("student.readinessCheckinSheet.copy020")
    static let readinessCheckinSheet021 = Key("student.readinessCheckinSheet.copy021")
    static let readinessCheckinSheet022 = Key("student.readinessCheckinSheet.copy022")
    static let readinessCheckinSheet023 = Key("student.readinessCheckinSheet.copy023")
    static let readinessCheckinSheet024 = Key("student.readinessCheckinSheet.copy024")
    static let readinessCheckinSheet025 = Key("student.readinessCheckinSheet.copy025")
    static let readinessCheckinSheet026 = Key("student.readinessCheckinSheet.copy026")
    static let readinessCheckinSheet027 = Key("student.readinessCheckinSheet.copy027")
    static let readinessCheckinViewModel001 = Key("student.readinessCheckinViewModel.copy001")
    static let readinessCheckinViewModel002 = Key("student.readinessCheckinViewModel.copy002")
    static let recorderAssetWriter001 = Key("student.recorderAssetWriter.copy001")
    static let recorderAssetWriter002 = Key("student.recorderAssetWriter.copy002")
    static let recorderAssetWriter003 = Key("student.recorderAssetWriter.copy003")
    static let recorderAssetWriter004 = Key("student.recorderAssetWriter.copy004")
    static let recorderAssetWriter005 = Key("student.recorderAssetWriter.copy005")
    static let recorderAssetWriter006 = Key("student.recorderAssetWriter.copy006")
    static let recorderSessionController001 = Key("student.recorderSessionController.copy001")
    static let recorderSessionController002 = Key("student.recorderSessionController.copy002")
    static let restTimerExplanationView001 = Key("student.restTimerExplanationView.copy001")
    static let restTimerExplanationView002 = Key("student.restTimerExplanationView.copy002")
    static let restTimerExplanationView003 = Key("student.restTimerExplanationView.copy003")
    static let restTimerExplanationView004 = Key("student.restTimerExplanationView.copy004")
    static let restTimerExplanationView005 = Key("student.restTimerExplanationView.copy005")
    static let restTimerOverlay001 = Key("student.restTimerOverlay.copy001")
    static let restTimerOverlay002 = Key("student.restTimerOverlay.copy002")
    static let restTimerOverlay003 = Key("student.restTimerOverlay.copy003")
    static let restTimerPreferenceRow001 = Key("student.restTimerPreferenceRow.copy001")
    static let restTimerSettingsView001 = Key("student.restTimerSettingsView.copy001")
    static let restTimerSettingsView002 = Key("student.restTimerSettingsView.copy002")
    static let restTimerSettingsView003 = Key("student.restTimerSettingsView.copy003")
    static let restTimerSettingsView004 = Key("student.restTimerSettingsView.copy004")
    static let restTimerSettingsView005 = Key("student.restTimerSettingsView.copy005")
    static let restTimerSettingsView006 = Key("student.restTimerSettingsView.copy006")
    static let restTimerSettingsView007 = Key("student.restTimerSettingsView.copy007")
    static let restTimerSettingsView008 = Key("student.restTimerSettingsView.copy008")
    static let restTimerSettingsView009 = Key("student.restTimerSettingsView.copy009")
    static let restTimerSettingsView010 = Key("student.restTimerSettingsView.copy010")
    static let restTimerSettingsView011 = Key("student.restTimerSettingsView.copy011")
    static let restTimerSettingsView012 = Key("student.restTimerSettingsView.copy012")
    static let restTimerSettingsView013 = Key("student.restTimerSettingsView.copy013")
    static let sessionSummaryView001 = Key("student.sessionSummaryView.copy001")
    static let sessionSummaryView002 = Key("student.sessionSummaryView.copy002")
    static let sessionSummaryView003 = Key("student.sessionSummaryView.copy003")
    static let sessionSummaryView004 = Key("student.sessionSummaryView.copy004")
    static let sessionSummaryView005 = Key("student.sessionSummaryView.copy005")
    static let sessionSummaryView006 = Key("student.sessionSummaryView.copy006")
    static let sessionSummaryView007 = Key("student.sessionSummaryView.copy007")
    static let sessionSummaryView008 = Key("student.sessionSummaryView.copy008")
    static let sessionSummaryView009 = Key("student.sessionSummaryView.copy009")
    static let sessionSummaryView010 = Key("student.sessionSummaryView.copy010")
    static let sessionSummaryView011 = Key("student.sessionSummaryView.copy011")
    static let sessionSummaryView012 = Key("student.sessionSummaryView.copy012")
    static let sessionSummaryView013 = Key("student.sessionSummaryView.copy013")
    static let sessionSummaryView014 = Key("student.sessionSummaryView.copy014")
    static let sessionSummaryView015 = Key("student.sessionSummaryView.copy015")
    static let sessionSummaryView016 = Key("student.sessionSummaryView.copy016")
    static let sessionSummaryView017 = Key("student.sessionSummaryView.copy017")
    static let sessionSummaryView018 = Key("student.sessionSummaryView.copy018")
    static let setEntryPlateLoadout001 = Key("student.setEntryPlateLoadout.copy001")
    static let setEntryPlateLoadout002 = Key("student.setEntryPlateLoadout.copy002")
    static let setEntryPlateLoadout003 = Key("student.setEntryPlateLoadout.copy003")
    static let setEntryRpe001 = Key("student.setEntryRpe.copy001")
    static let setEntryRpe002 = Key("student.setEntryRpe.copy002")
    static let setEntryRpe003 = Key("student.setEntryRpe.copy003")
    static let setEntryRpe004 = Key("student.setEntryRpe.copy004")
    static let setEntryRpe005 = Key("student.setEntryRpe.copy005")
    static let setEntryRpe006 = Key("student.setEntryRpe.copy006")
    static let setEntryRpe007 = Key("student.setEntryRpe.copy007")
    static let setEntryRpe008 = Key("student.setEntryRpe.copy008")
    static let setEntryRpe009 = Key("student.setEntryRpe.copy009")
    static let setEntryRpe010 = Key("student.setEntryRpe.copy010")
    static let setEntryRpe011 = Key("student.setEntryRpe.copy011")
    static let setEntryRpescale001 = Key("student.setEntryRpescale.copy001")
    static let setEntrySheet001 = Key("student.setEntrySheet.copy001")
    static let setEntrySheet002 = Key("student.setEntrySheet.copy002")
    static let setEntrySheet003 = Key("student.setEntrySheet.copy003")
    static let setEntrySheet004 = Key("student.setEntrySheet.copy004")
    static let setEntrySheet005 = Key("student.setEntrySheet.copy005")
    static let setEntrySheet006 = Key("student.setEntrySheet.copy006")
    static let setEntrySheet007 = Key("student.setEntrySheet.copy007")
    static let setEntrySheet008 = Key("student.setEntrySheet.copy008")
    static let setEntrySheet009 = Key("student.setEntrySheet.copy009")
    static let setEntrySheet010 = Key("student.setEntrySheet.copy010")
    static let setEntrySheet011 = Key("student.setEntrySheet.copy011")
    static let setEntrySheet012 = Key("student.setEntrySheet.copy012")
    static let setVideoUploadIndicator001 = Key("student.setVideoUploadIndicator.copy001")
    static let setVideoUploadIndicator002 = Key("student.setVideoUploadIndicator.copy002")
    static let setVideoUploadIndicator003 = Key("student.setVideoUploadIndicator.copy003")
    static let step1BasicsSection001 = Key("student.step1BasicsSection.copy001")
    static let step1BasicsSection002 = Key("student.step1BasicsSection.copy002")
    static let step1BasicsSection003 = Key("student.step1BasicsSection.copy003")
    static let step1BasicsSection004 = Key("student.step1BasicsSection.copy004")
    static let step1BasicsSection005 = Key("student.step1BasicsSection.copy005")
    static let step1BasicsSection006 = Key("student.step1BasicsSection.copy006")
    static let step1BasicsSection007 = Key("student.step1BasicsSection.copy007")
    static let step2BackgroundSection001 = Key("student.step2BackgroundSection.copy001")
    static let step2BackgroundSection002 = Key("student.step2BackgroundSection.copy002")
    static let step2BackgroundSection003 = Key("student.step2BackgroundSection.copy003")
    static let step2BackgroundSection004 = Key("student.step2BackgroundSection.copy004")
    static let step2BackgroundSection005 = Key("student.step2BackgroundSection.copy005")
    static let step2BackgroundSection006 = Key("student.step2BackgroundSection.copy006")
    static let step2BackgroundSection007 = Key("student.step2BackgroundSection.copy007")
    static let step3StrengthSection001 = Key("student.step3StrengthSection.copy001")
    static let step3StrengthSection002 = Key("student.step3StrengthSection.copy002")
    static let step3StrengthSection003 = Key("student.step3StrengthSection.copy003")
    static let step3StrengthSection004 = Key("student.step3StrengthSection.copy004")
    static let step3StrengthSection005 = Key("student.step3StrengthSection.copy005")
    static let step3StrengthSection006 = Key("student.step3StrengthSection.copy006")
    static let step3StrengthSection007 = Key("student.step3StrengthSection.copy007")
    static let step3StrengthSection008 = Key("student.step3StrengthSection.copy008")
    static let step3StrengthSection009 = Key("student.step3StrengthSection.copy009")
    static let step3StrengthSection010 = Key("student.step3StrengthSection.copy010")
    static let step3StrengthSection011 = Key("student.step3StrengthSection.copy011")
    static let step3StrengthSection012 = Key("student.step3StrengthSection.copy012")
    static let step3StrengthSection013 = Key("student.step3StrengthSection.copy013")
    static let step3StrengthSection014 = Key("student.step3StrengthSection.copy014")
    static let step4EnvironmentSection001 = Key("student.step4EnvironmentSection.copy001")
    static let step4EnvironmentSection002 = Key("student.step4EnvironmentSection.copy002")
    static let step4EnvironmentSection003 = Key("student.step4EnvironmentSection.copy003")
    static let step4EnvironmentSection004 = Key("student.step4EnvironmentSection.copy004")
    static let step4EnvironmentSection005 = Key("student.step4EnvironmentSection.copy005")
    static let step4EnvironmentSection006 = Key(
      "student.step4EnvironmentSection.copy006",
      one: "student.step4EnvironmentSection.copy006.one"
    )
    static let step4EnvironmentSection007 = Key("student.step4EnvironmentSection.copy007")
    static let step4EnvironmentSection008 = Key("student.step4EnvironmentSection.copy008")
    static let step4EnvironmentSection009 = Key("student.step4EnvironmentSection.copy009")
    static let step4EnvironmentSection010 = Key("student.step4EnvironmentSection.copy010")
    static let step4EnvironmentSection011 = Key("student.step4EnvironmentSection.copy011")
    static let step4EnvironmentSection012 = Key("student.step4EnvironmentSection.copy012")
    static let step4EnvironmentSection013 = Key("student.step4EnvironmentSection.copy013")
    static let step4EnvironmentSection014 = Key("student.step4EnvironmentSection.copy014")
    static let step4EnvironmentSection015 = Key("student.step4EnvironmentSection.copy015")
    static let step4EnvironmentSection016 = Key("student.step4EnvironmentSection.copy016")
    static let step4EnvironmentSection017 = Key("student.step4EnvironmentSection.copy017")
    static let step4EnvironmentSection018 = Key("student.step4EnvironmentSection.copy018")
    static let step5RecoverySection001 = Key("student.step5RecoverySection.copy001")
    static let step5RecoverySection002 = Key("student.step5RecoverySection.copy002")
    static let step5RecoverySection003 = Key("student.step5RecoverySection.copy003")
    static let step5RecoverySection004 = Key("student.step5RecoverySection.copy004")
    static let step5RecoverySection005 = Key("student.step5RecoverySection.copy005")
    static let step5RecoverySection006 = Key("student.step5RecoverySection.copy006")
    static let step6MaterialsSection001 = Key("student.step6MaterialsSection.copy001")
    static let step6MaterialsSection002 = Key("student.step6MaterialsSection.copy002")
    static let step6MaterialsSection003 = Key("student.step6MaterialsSection.copy003")
    static let step6MaterialsSection004 = Key("student.step6MaterialsSection.copy004")
    static let step6MaterialsSection005 = Key("student.step6MaterialsSection.copy005")
    static let step7ExtrasSection001 = Key("student.step7ExtrasSection.copy001")
    static let step7ExtrasSection002 = Key("student.step7ExtrasSection.copy002")
    static let step7ExtrasSection003 = Key("student.step7ExtrasSection.copy003")
    static let step7ExtrasSection004 = Key("student.step7ExtrasSection.copy004")
    static let step7ExtrasSection005 = Key("student.step7ExtrasSection.copy005")
    static let step7ExtrasSection006 = Key("student.step7ExtrasSection.copy006")
    static let step7ExtrasSection007 = Key("student.step7ExtrasSection.copy007")
    static let step7ExtrasSection008 = Key("student.step7ExtrasSection.copy008")
    static let step7ExtrasSection009 = Key("student.step7ExtrasSection.copy009")
    static let step7ExtrasSection010 = Key("student.step7ExtrasSection.copy010")
    static let step7ExtrasSection011 = Key("student.step7ExtrasSection.copy011")
    static let studentBlackGoldChatView001 = Key("student.studentBlackGoldChatView.copy001")
    static let studentBlackGoldChatView002 = Key("student.studentBlackGoldChatView.copy002")
    static let studentBlackGoldChatView003 = Key("student.studentBlackGoldChatView.copy003")
    static let studentBlackGoldChatView004 = Key("student.studentBlackGoldChatView.copy004")
    static let studentBlackGoldChatView005 = Key("student.studentBlackGoldChatView.copy005")
    static let studentBlackGoldChatView006 = Key("student.studentBlackGoldChatView.copy006")
    static let studentBlackGoldChatView007 = Key("student.studentBlackGoldChatView.copy007")
    static let studentBlackGoldChatView008 = Key("student.studentBlackGoldChatView.copy008")
    static let studentBlackGoldChatView009 = Key("student.studentBlackGoldChatView.copy009")
    static let studentBlackGoldChatView010 = Key("student.studentBlackGoldChatView.copy010")
    static let studentBlackGoldChatView011 = Key("student.studentBlackGoldChatView.copy011")
    static let studentBlackGoldChatView012 = Key("student.studentBlackGoldChatView.copy012")
    static let studentBlackGoldChatView013 = Key("student.studentBlackGoldChatView.copy013")
    static let studentBlackGoldChatView014 = Key("student.studentBlackGoldChatView.copy014")
    static let studentBlackGoldChatView015 = Key("student.studentBlackGoldChatView.copy015")
    static let studentBlackGoldChatView016 = Key("student.studentBlackGoldChatView.copy016")
    static let studentBlackGoldChatView017 = Key("student.studentBlackGoldChatView.copy017")
    static let studentBlackGoldChatView018 = Key("student.studentBlackGoldChatView.copy018")
    static let studentBlackGoldChatView019 = Key("student.studentBlackGoldChatView.copy019")
    static let studentBlackGoldChatView020 = Key("student.studentBlackGoldChatView.copy020")
    static let studentBlackGoldChatView021 = Key("student.studentBlackGoldChatView.copy021")
    static let studentBlackGoldChatView022 = Key("student.studentBlackGoldChatView.copy022")
    static let studentBlackGoldChatView023 = Key("student.studentBlackGoldChatView.copy023")
    static let studentBlackGoldChatView024 = Key("student.studentBlackGoldChatView.copy024")
    static let studentBlackGoldChatView025 = Key("student.studentBlackGoldChatView.copy025")
    static let studentBlackGoldChatView026 = Key("student.studentBlackGoldChatView.copy026")
    static let studentChatTimeline001 = Key("student.studentChatTimeline.copy001")
    static let studentChatTimeline002 = Key("student.studentChatTimeline.copy002")
    static let studentChatTimeline003 = Key("student.studentChatTimeline.copy003")
    static let studentDemoFeedbackVideo001 = Key("student.studentDemoFeedbackVideo.copy001")
    static let studentDemoSeed001 = Key("student.studentDemoSeed.copy001")
    static let studentDemoSeed002 = Key("student.studentDemoSeed.copy002")
    static let studentDemoSeed003 = Key("student.studentDemoSeed.copy003")
    static let studentDemoSeed004 = Key("student.studentDemoSeed.copy004")
    static let studentDemoSeed005 = Key("student.studentDemoSeed.copy005")
    static let studentDemoSeed006 = Key("student.studentDemoSeed.copy006")
    static let studentDemoSeed007 = Key("student.studentDemoSeed.copy007")
    static let studentDemoSeed008 = Key("student.studentDemoSeed.copy008")
    static let studentDemoSeed009 = Key("student.studentDemoSeed.copy009")
    static let studentDemoSeed010 = Key("student.studentDemoSeed.copy010")
    static let studentDemoSeed011 = Key("student.studentDemoSeed.copy011")
    static let studentDemoSeed012 = Key("student.studentDemoSeed.copy012")
    static let studentDemoSeed013 = Key("student.studentDemoSeed.copy013")
    static let studentDemoSeed014 = Key("student.studentDemoSeed.copy014")
    static let studentDemoSeed015 = Key("student.studentDemoSeed.copy015")
    static let studentRestTimerSettings001 = Key("student.studentRestTimerSettings.copy001")
    static let studentRestTimerSettings002 = Key("student.studentRestTimerSettings.copy002")
    static let studentRestTimerSettings003 = Key("student.studentRestTimerSettings.copy003")
    static let studentRootView001 = Key("student.studentRootView.copy001")
    static let studentRootView002 = Key("student.studentRootView.copy002")
    static let studentRootView003 = Key("student.studentRootView.copy003")
    static let studentRootView004 = Key("student.studentRootView.copy004")
    static let todayWorkoutExerciseSection001 = Key("student.todayWorkoutExerciseSection.copy001")
    static let todayWorkoutExerciseSection002 = Key("student.todayWorkoutExerciseSection.copy002")
    static let todayWorkoutPresentation001 = Key("student.todayWorkoutPresentation.copy001")
    static let todayWorkoutPresentation002 = Key("student.todayWorkoutPresentation.copy002")
    static let todayWorkoutPresentation003 = Key("student.todayWorkoutPresentation.copy003")
    static let todayWorkoutPresentation004 = Key("student.todayWorkoutPresentation.copy004")
    static let todayWorkoutPresentation005 = Key("student.todayWorkoutPresentation.copy005")
    static let todayWorkoutScreen001 = Key("student.todayWorkoutScreen.copy001")
    static let todayWorkoutScreen002 = Key("student.todayWorkoutScreen.copy002")
    static let todayWorkoutScreen003 = Key("student.todayWorkoutScreen.copy003")
    static let todayWorkoutScreen004 = Key("student.todayWorkoutScreen.copy004")
    static let todayWorkoutScreen005 = Key("student.todayWorkoutScreen.copy005")
    static let todayWorkoutScreen006 = Key("student.todayWorkoutScreen.copy006")
    static let todayWorkoutScreen007 = Key("student.todayWorkoutScreen.copy007")
    static let todayWorkoutScreen008 = Key("student.todayWorkoutScreen.copy008")
    static let todayWorkoutScreen009 = Key("student.todayWorkoutScreen.copy009")
    static let todayWorkoutScreen010 = Key("student.todayWorkoutScreen.copy010")
    static let todayWorkoutScreen011 = Key("student.todayWorkoutScreen.copy011")
    static let todayWorkoutScreen012 = Key("student.todayWorkoutScreen.copy012")
    static let todayWorkoutScreen013 = Key("student.todayWorkoutScreen.copy013")
    static let todayWorkoutScreen014 = Key("student.todayWorkoutScreen.copy014")
    static let todayWorkoutScreen015 = Key("student.todayWorkoutScreen.copy015")
    static let todayWorkoutScreen016 = Key("student.todayWorkoutScreen.copy016")
    static let todayWorkoutScreen017 = Key("student.todayWorkoutScreen.copy017")
    static let todayWorkoutScreen018 = Key(
      "student.todayWorkoutScreen.copy018",
      one: "student.todayWorkoutScreen.copy018.one"
    )
    static let todayWorkoutScreen019 = Key(
      "student.todayWorkoutScreen.copy019",
      one: "student.todayWorkoutScreen.copy019.one"
    )
    static let todayWorkoutScreen020 = Key(
      "student.todayWorkoutScreen.copy020",
      one: "student.todayWorkoutScreen.copy020.one",
      countIndex: 2
    )
    static let todayWorkoutScreen021 = Key("student.todayWorkoutScreen.copy021")
    static let todayWorkoutScreen022 = Key("student.todayWorkoutScreen.copy022")
    static let todayWorkoutScreen023 = Key("student.todayWorkoutScreen.copy023")
    static let todayWorkoutScreen024 = Key("student.todayWorkoutScreen.copy024")
    static let todayWorkoutScreen025 = Key("student.todayWorkoutScreen.copy025")
    static let todayWorkoutScreen026 = Key("student.todayWorkoutScreen.copy026")
    static let todayWorkoutTypes001 = Key("student.todayWorkoutTypes.copy001")
    static let todayWorkoutTypes002 = Key("student.todayWorkoutTypes.copy002")
    static let todayWorkoutTypes003 = Key("student.todayWorkoutTypes.copy003")
    static let todayWorkoutTypes004 = Key("student.todayWorkoutTypes.copy004")
    static let todayWorkoutTypes005 = Key("student.todayWorkoutTypes.copy005")
    static let todayWorkoutTypes006 = Key("student.todayWorkoutTypes.copy006")
    static let todayWorkoutTypes007 = Key("student.todayWorkoutTypes.copy007")
    static let todayWorkoutV3Previews001 = Key("student.todayWorkoutV3Previews.copy001")
    static let todayWorkoutV3Previews002 = Key("student.todayWorkoutV3Previews.copy002")
    static let todayWorkoutV3Previews003 = Key("student.todayWorkoutV3Previews.copy003")
    static let todayWorkoutV3Previews004 = Key("student.todayWorkoutV3Previews.copy004")
    static let todayWorkoutV3Previews005 = Key("student.todayWorkoutV3Previews.copy005")
    static let todayWorkoutV3Previews006 = Key("student.todayWorkoutV3Previews.copy006")
    static let todayWorkoutV3Previews007 = Key("student.todayWorkoutV3Previews.copy007")
    static let todayWorkoutV3Previews008 = Key("student.todayWorkoutV3Previews.copy008")
    static let todayWorkoutV3Previews009 = Key("student.todayWorkoutV3Previews.copy009")
    static let todayWorkoutV3Previews010 = Key("student.todayWorkoutV3Previews.copy010")
    static let todayWorkoutV3Previews011 = Key("student.todayWorkoutV3Previews.copy011")
    static let todayWorkoutV3Previews012 = Key("student.todayWorkoutV3Previews.copy012")
    static let todayWorkoutV3Previews013 = Key("student.todayWorkoutV3Previews.copy013")
    static let todayWorkoutV3Previews014 = Key("student.todayWorkoutV3Previews.copy014")
    static let todayWorkoutV3Previews015 = Key("student.todayWorkoutV3Previews.copy015")
    static let todayWorkoutV3Previews016 = Key("student.todayWorkoutV3Previews.copy016")
    static let todayWorkoutV3Previews017 = Key("student.todayWorkoutV3Previews.copy017")
    static let todayWorkoutV3Previews018 = Key("student.todayWorkoutV3Previews.copy018")
    static let todayWorkoutV3Previews019 = Key("student.todayWorkoutV3Previews.copy019")
    static let todayWorkoutV3Previews020 = Key("student.todayWorkoutV3Previews.copy020")
    static let todayWorkoutV3Previews021 = Key("student.todayWorkoutV3Previews.copy021")
    static let todayWorkoutV3Previews022 = Key("student.todayWorkoutV3Previews.copy022")
    static let todayWorkoutV3Previews023 = Key("student.todayWorkoutV3Previews.copy023")
    static let todayWorkoutV3Previews024 = Key("student.todayWorkoutV3Previews.copy024")
    static let todayWorkoutV3Previews025 = Key("student.todayWorkoutV3Previews.copy025")
    static let todayWorkoutV3Previews026 = Key("student.todayWorkoutV3Previews.copy026")
    static let todayWorkoutView001 = Key("student.todayWorkoutView.copy001")
    static let todayWorkoutView002 = Key("student.todayWorkoutView.copy002")
    static let todayWorkoutView003 = Key("student.todayWorkoutView.copy003")
    static let todayWorkoutView004 = Key("student.todayWorkoutView.copy004")
    static let todayWorkoutView005 = Key("student.todayWorkoutView.copy005")
    static let todayWorkoutView006 = Key("student.todayWorkoutView.copy006")
    static let todayWorkoutView007 = Key("student.todayWorkoutView.copy007")
    static let todayWorkoutView008 = Key("student.todayWorkoutView.copy008")
    static let todayWorkoutView009 = Key("student.todayWorkoutView.copy009")
    static let todayWorkoutView010 = Key("student.todayWorkoutView.copy010")
    static let todayWorkoutView011 = Key("student.todayWorkoutView.copy011")
    static let todayWorkoutViewModel001 = Key("student.todayWorkoutViewModel.copy001")
    static let todayWorkoutViewModel002 = Key("student.todayWorkoutViewModel.copy002")
    static let todayWorkoutViewModel003 = Key("student.todayWorkoutViewModel.copy003")
    static let todayWorkoutViewModelRecordingError001 = Key(
      "student.todayWorkoutViewModelRecordingError.copy001")
    static let todayWorkoutViewModelRecordingError002 = Key(
      "student.todayWorkoutViewModelRecordingError.copy002")
    static let todayWorkoutViewModelRecordingError003 = Key(
      "student.todayWorkoutViewModelRecordingError.copy003")
    static let todayWorkoutViewModelRecordingError004 = Key(
      "student.todayWorkoutViewModelRecordingError.copy004")
    static let todayWorkoutViewModelRecordingError005 = Key(
      "student.todayWorkoutViewModelRecordingError.copy005")
    static let trainingCalendarLogic001 = Key("student.trainingCalendarLogic.copy001")
    static let trainingCalendarLogic002 = Key("student.trainingCalendarLogic.copy002")
    static let trainingCalendarLogic003 = Key("student.trainingCalendarLogic.copy003")
    static let trainingCalendarLogic004 = Key("student.trainingCalendarLogic.copy004")
    static let trainingCalendarLogic005 = Key("student.trainingCalendarLogic.copy005")
    static let trainingCalendarLogic006 = Key("student.trainingCalendarLogic.copy006")
    static let trainingCalendarLogic007 = Key("student.trainingCalendarLogic.copy007")
    static let trainingCalendarLogic008 = Key("student.trainingCalendarLogic.copy008")
    static let trainingCalendarLogic009 = Key("student.trainingCalendarLogic.copy009")
    static let trainingCalendarLogic010 = Key("student.trainingCalendarLogic.copy010")
    static let trainingCalendarLogic011 = Key("student.trainingCalendarLogic.copy011")
    static let trainingCalendarLogic012 = Key("student.trainingCalendarLogic.copy012")
    static let trainingCalendarLogic013 = Key("student.trainingCalendarLogic.copy013")
    static let trainingCalendarView001 = Key("student.trainingCalendarView.copy001")
    static let trainingCalendarView002 = Key(
      "student.trainingCalendarView.copy002",
      one: "student.trainingCalendarView.copy002.one",
      countIndex: 1
    )
    static let trainingCalendarView003 = Key(
      "student.trainingCalendarView.copy003",
      one: "student.trainingCalendarView.copy003.one",
      countIndex: 1
    )
    static let trainingCalendarView004 = Key("student.trainingCalendarView.copy004")
    static let trainingCalendarView005 = Key(
      "student.trainingCalendarView.copy005",
      one: "student.trainingCalendarView.copy005.one"
    )
    static let trainingCalendarView006 = Key("student.trainingCalendarView.copy006")
    static let trainingHistoryView001 = Key("student.trainingHistoryView.copy001")
    static let trainingHistoryView002 = Key("student.trainingHistoryView.copy002")
    static let trainingHistoryView003 = Key("student.trainingHistoryView.copy003")
    static let trainingHistoryView004 = Key("student.trainingHistoryView.copy004")
    static let trainingHistoryView005 = Key("student.trainingHistoryView.copy005")
    static let trainingHistoryView006 = Key("student.trainingHistoryView.copy006")
    static let trainingHistoryView007 = Key("student.trainingHistoryView.copy007")
    static let trainingHistoryView008 = Key("student.trainingHistoryView.copy008")
    static let trainingHistoryView009 = Key("student.trainingHistoryView.copy009")
    static let trainingHistoryView010 = Key("student.trainingHistoryView.copy010")
    static let trainingHistoryView011 = Key("student.trainingHistoryView.copy011")
    static let trainingHistoryView012 = Key("student.trainingHistoryView.copy012")
    static let trainingHistoryView013 = Key("student.trainingHistoryView.copy013")
    static let trainingHistoryView014 = Key("student.trainingHistoryView.copy014")
    static let trainingHistoryView015 = Key("student.trainingHistoryView.copy015")
    static let trainingHistoryView016 = Key("student.trainingHistoryView.copy016")
    static let trainingHistoryView017 = Key("student.trainingHistoryView.copy017")
    static let trainingHistoryView018 = Key("student.trainingHistoryView.copy018")
    static let trainingHistoryView019 = Key("student.trainingHistoryView.copy019")
    static let trainingHistoryView020 = Key("student.trainingHistoryView.copy020")
    static let trainingHistoryView021 = Key("student.trainingHistoryView.copy021")
    static let trainingHistoryView022 = Key("student.trainingHistoryView.copy022")
    static let trainingHistoryView023 = Key("student.trainingHistoryView.copy023")
    static let trainingHistoryView024 = Key("student.trainingHistoryView.copy024")
    static let trainingReminderCopy001 = Key("student.trainingReminderCopy.copy001")
    static let trainingReminderCopy002 = Key("student.trainingReminderCopy.copy002")
    static let trainingReminderCopy003 = Key("student.trainingReminderCopy.copy003")
    static let trainingReminderCopy004 = Key("student.trainingReminderCopy.copy004")
    static let trainingReminderPreferenceRow001 = Key(
      "student.trainingReminderPreferenceRow.copy001")
    static let trainingReminderSettingsView001 = Key(
      "student.trainingReminderSettingsView.copy001")
    static let trainingReminderSettingsView002 = Key(
      "student.trainingReminderSettingsView.copy002")
    static let trainingReminderSettingsView003 = Key(
      "student.trainingReminderSettingsView.copy003")
    static let trainingReminderSettingsView004 = Key(
      "student.trainingReminderSettingsView.copy004")
    static let trainingReminderSettingsView005 = Key(
      "student.trainingReminderSettingsView.copy005")
    static let trainingReminderSettingsView006 = Key(
      "student.trainingReminderSettingsView.copy006")
    static let trainingReminderSettingsView007 = Key(
      "student.trainingReminderSettingsView.copy007")
    static let trainingReminderSettingsView008 = Key(
      "student.trainingReminderSettingsView.copy008")
    static let trainingReminderWeekday001 = Key("student.trainingReminderWeekday.copy001")
    static let trainingReminderWeekday002 = Key("student.trainingReminderWeekday.copy002")
    static let trainingReminderWeekday003 = Key("student.trainingReminderWeekday.copy003")
    static let trainingReminderWeekday004 = Key("student.trainingReminderWeekday.copy004")
    static let trainingReminderWeekday005 = Key("student.trainingReminderWeekday.copy005")
    static let trainingReminderWeekday006 = Key("student.trainingReminderWeekday.copy006")
    static let trainingReminderWeekday007 = Key("student.trainingReminderWeekday.copy007")
    static let uploadFailureNotifier001 = Key("student.uploadFailureNotifier.copy001")
    static let uploadFailureNotifier002 = Key(
      "student.uploadFailureNotifier.copy002",
      one: "student.uploadFailureNotifier.copy002.one"
    )
    static let videoAttachmentSection001 = Key("student.videoAttachmentSection.copy001")
    static let videoAttachmentSection002 = Key("student.videoAttachmentSection.copy002")
    static let videoAttachmentSection003 = Key("student.videoAttachmentSection.copy003")
    static let videoAttachmentSection004 = Key("student.videoAttachmentSection.copy004")
    static let videoAttachmentV3Controls001 = Key("student.videoAttachmentV3Controls.copy001")
    static let videoAttachmentV3Controls002 = Key("student.videoAttachmentV3Controls.copy002")
    static let videoAttachmentV3Controls003 = Key("student.videoAttachmentV3Controls.copy003")
    static let videoAttachmentV3Controls004 = Key("student.videoAttachmentV3Controls.copy004")
    static let videoAttachmentV3Controls005 = Key("student.videoAttachmentV3Controls.copy005")
    static let videoAttachmentV3Controls006 = Key("student.videoAttachmentV3Controls.copy006")
    static let videoAttachmentV3Controls007 = Key("student.videoAttachmentV3Controls.copy007")
    static let videoAttachmentV3Controls008 = Key("student.videoAttachmentV3Controls.copy008")
    static let videoAttachmentV3Controls009 = Key("student.videoAttachmentV3Controls.copy009")
    static let videoAttachmentV3Previews001 = Key("student.videoAttachmentV3Previews.copy001")
    static let videoAttachmentViewModel001 = Key("student.videoAttachmentViewModel.copy001")
    static let videoAttachmentViewModel002 = Key("student.videoAttachmentViewModel.copy002")
    static let videoAttachmentViewModel003 = Key("student.videoAttachmentViewModel.copy003")
    static let videoAttachmentViewModel004 = Key("student.videoAttachmentViewModel.copy004")
    static let videoPrivacyCopy001 = Key("student.videoPrivacyCopy.copy001")
    static let videoPrivacyCopy002 = Key("student.videoPrivacyCopy.copy002")
    static let videoPrivacyCopy003 = Key("student.videoPrivacyCopy.copy003")
    static let videoPrivacyCopy004 = Key("student.videoPrivacyCopy.copy004")
    static let videoTrimTimeline001 = Key("student.videoTrimTimeline.copy001")
    static let videoTrimTimeline002 = Key("student.videoTrimTimeline.copy002")
    static let videoTrimTimeline003 = Key("student.videoTrimTimeline.copy003")
    static let videoTrimTimeline004 = Key("student.videoTrimTimeline.copy004")
    static let videoTrimView001 = Key("student.videoTrimView.copy001")
    static let videoTrimView002 = Key("student.videoTrimView.copy002")
    static let videoTrimView003 = Key("student.videoTrimView.copy003")
    static let videoTrimView004 = Key("student.videoTrimView.copy004")
    static let videoTrimView005 = Key("student.videoTrimView.copy005")
    static let volumeIntensityChart001 = Key("student.volumeIntensityChart.copy001")
    static let volumeIntensityChart002 = Key("student.volumeIntensityChart.copy002")
    static let volumeIntensityChart003 = Key("student.volumeIntensityChart.copy003")
    static let volumeIntensityChart004 = Key(
      "student.volumeIntensityChart.copy004",
      one: "student.volumeIntensityChart.copy004.one"
    )
    static let w4V3Previews001 = Key("student.w4V3Previews.copy001")
    static let w4V3Previews002 = Key("student.w4V3Previews.copy002")
    static let w4V3Previews003 = Key("student.w4V3Previews.copy003")
    static let w4V3Previews004 = Key("student.w4V3Previews.copy004")
    static let w4V3Previews005 = Key("student.w4V3Previews.copy005")
    static let workoutCompletionFlowView001 = Key("student.workoutCompletionFlowView.copy001")
    static let workoutCompletionFlowView002 = Key("student.workoutCompletionFlowView.copy002")
    static let workoutCompletionFlowView003 = Key("student.workoutCompletionFlowView.copy003")
    static let workoutCompletionFlowView004 = Key("student.workoutCompletionFlowView.copy004")
    static let workoutCompletionFlowView005 = Key(
      "student.workoutCompletionFlowView.copy005",
      one: "student.workoutCompletionFlowView.copy005.one"
    )
    static let workoutCompletionFlowView006 = Key(
      "student.workoutCompletionFlowView.copy006",
      one: "student.workoutCompletionFlowView.copy006.one"
    )
    static let workoutCompletionFlowView007 = Key("student.workoutCompletionFlowView.copy007")
    static let workoutCompletionPresentation001 = Key(
      "student.workoutCompletionPresentation.copy001")
    static let workoutCompletionPresentation002 = Key(
      "student.workoutCompletionPresentation.copy002",
      one: "student.workoutCompletionPresentation.copy002.one"
    )
    static let workoutCompletionPresentation003 = Key(
      "student.workoutCompletionPresentation.copy003",
      one: "student.workoutCompletionPresentation.copy003.one"
    )
    static let workoutCompletionPresentation004 = Key(
      "student.workoutCompletionPresentation.copy004",
      one: "student.workoutCompletionPresentation.copy004.one"
    )
    static let workoutCompletionPresentation005 = Key(
      "student.workoutCompletionPresentation.copy005",
      one: "student.workoutCompletionPresentation.copy005.one"
    )
    static let workoutCompletionPresentation006 = Key(
      "student.workoutCompletionPresentation.copy006")
    static let workoutCompletionPresentation007 = Key(
      "student.workoutCompletionPresentation.copy007")
    static let workoutCompletionPresentation008 = Key(
      "student.workoutCompletionPresentation.copy008")
    static let workoutCompletionPresentation009 = Key(
      "student.workoutCompletionPresentation.copy009")
    static let workoutCompletionPresentation010 = Key(
      "student.workoutCompletionPresentation.copy010")
    static let workoutCompletionPresentation011 = Key(
      "student.workoutCompletionPresentation.copy011")
    static let workoutCompletionPresentation012 = Key(
      "student.workoutCompletionPresentation.copy012")
    static let workoutCompletionPresentation013 = Key(
      "student.workoutCompletionPresentation.copy013")
    static let workoutCompletionPresentation014 = Key(
      "student.workoutCompletionPresentation.copy014")
    static let workoutCompletionPresentation015 = Key(
      "student.workoutCompletionPresentation.copy015")
    static let workoutCompletionPresentation016 = Key(
      "student.workoutCompletionPresentation.copy016")
  }

  static func localized(_ key: Key, locale: Locale = .current) -> String {
    resolved(
      String(localized: key.value, bundle: .module, locale: locale),
      locale: locale
    )
  }

  static func replacing(
    _ key: Key,
    values: [String],
    locale: Locale = .current
  ) -> String {
    let localizedKey: Key
    if isEnglish(locale),
      values.indices.contains(key.countIndex),
      Int(values[key.countIndex]) == 1,
      let oneValue = key.oneValue
    {
      localizedKey = Key(oneValue)
    } else {
      localizedKey = key
    }

    return values.enumerated().reduce(localized(localizedKey, locale: locale)) { result, pair in
      result.replacing("{\(pair.offset)}", with: pair.element)
    }
  }

  static func listSeparated(_ values: [String], locale: Locale = .current) -> String {
    values.joined(separator: isEnglish(locale) ? ", " : "、")
  }

  static func commaSeparated(_ values: [String], locale: Locale = .current) -> String {
    values.joined(separator: isEnglish(locale) ? ", " : "，")
  }

  private static func isEnglish(_ locale: Locale) -> Bool {
    locale.language.languageCode?.identifier == "en"
  }

  private static func localized(_ key: String.LocalizationValue) -> String {
    resolved(String(localized: key, bundle: .module), locale: .current)
  }

  private static func resolved(_ localized: String, locale: Locale) -> String {
    #if DEBUG && os(macOS)
      guard localized.hasPrefix("student."),
        let value = macOSSwiftPMCatalog[localized]?[isEnglish(locale) ? "en" : "zh-Hans"]
      else {
        return localized
      }
      return value
    #else
      return localized
    #endif
  }

  #if DEBUG && os(macOS)
    /// SwiftPM copies string catalogs into macOS test bundles without compiling
    /// them to `.lproj`; iOS and Release builds always use `String(localized:)`.
    private static let macOSSwiftPMCatalog: [String: [String: String]] = {
      guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
        let data = try? Data(contentsOf: url),
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let strings = root["strings"] as? [String: Any]
      else {
        return [:]
      }

      return strings.reduce(into: [:]) { result, pair in
        guard let entry = pair.value as? [String: Any],
          let localizations = entry["localizations"] as? [String: Any]
        else {
          return
        }
        result[pair.key] = localizations.reduce(into: [:]) { values, localization in
          guard let payload = localization.value as? [String: Any],
            let stringUnit = payload["stringUnit"] as? [String: Any],
            let value = stringUnit["value"] as? String
          else {
            return
          }
          values[localization.key] = value
        }
      }
    }()
  #endif
}
// swiftlint:enable file_length
