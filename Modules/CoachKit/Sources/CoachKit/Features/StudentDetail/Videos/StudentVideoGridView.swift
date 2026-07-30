import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentVideoGridView: View {
  let videos: [StudentVideo]
  let unavailable: Bool
  let now: Date
  let planDays: [StudentPlanDay]
  let feedbackVideoIDs: Set<UUID>
  @Bindable private var viewModel: StudentVideoGridViewModel

  init(
    videos: [StudentVideo],
    unavailable: Bool,
    now: Date,
    planDays: [StudentPlanDay],
    feedbackVideoIDs: Set<UUID>,
    viewModel: StudentVideoGridViewModel
  ) {
    self.videos = videos
    self.unavailable = unavailable
    self.now = now
    self.planDays = planDays
    self.feedbackVideoIDs = feedbackVideoIDs
    self.viewModel = viewModel
  }

  var body: some View {
    content
      .background(Color.MeetPR.bgBase)
      #if os(iOS)
        .fullScreenCover(item: $viewModel.playbackItem) { item in
          CoachVideoPlayerView(
            videoID: item.id,
            url: item.url,
            refreshURL: { try await viewModel.freshPlaybackURL(videoID: $0) }
          )
        }
      #else
        .sheet(item: $viewModel.playbackItem) { item in
          CoachVideoPlayerView(
            videoID: item.id,
            url: item.url,
            refreshURL: { try await viewModel.freshPlaybackURL(videoID: $0) }
          )
        }
      #endif
  }

  @ViewBuilder
  private var content: some View {
    if unavailable {
      message(
        CoachVideoStrings.loadFailed,
        subtitle: CoachVideoStrings.pullToRetry
      )
    } else if videos.isEmpty {
      message(
        CoachVideoStrings.emptyTitle,
        subtitle: CoachVideoStrings.emptySubtitle
      )
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point10) {
          if let playbackError = viewModel.playbackError {
            playbackErrorBanner(playbackError)
          }
          ForEach(StudentVideoGridViewModel.makeSections(videos: videos)) { section in
            Text(sectionTitle(section.day))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.textTertiary)
              .padding(.top, MeetPRSpacing.space1)
            ForEach(section.videos) { video in
              videoRow(video)
            }
          }
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.bottom, MeetPRSpacing.point28)
      }
      .scrollIndicators(.hidden)
    }
  }

  private func videoRow(_ video: StudentVideo) -> some View {
    Button {
      Task { await viewModel.play(video) }
    } label: {
      HStack(spacing: MeetPRSpacing.point13) {
        ZStack {
          RoundedRectangle(cornerRadius: MeetPRRadius.inset)
            .fill(Color.MeetPR.textPrimary)
            .frame(width: 72, height: 56)
          if viewModel.loadingVideoID == video.id {
            ProgressView()
              .tint(Color.MeetPR.inkOnCTAFill)
          } else {
            Image(systemName: "play.fill")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size20))
              .foregroundStyle(Color.MeetPR.inkOnCTAFill)
          }
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
          Text(videoLabel(video))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .lineLimit(1)
          HStack(spacing: MeetPRSpacing.point6) {
            Text(
              feedbackVideoIDs.contains(video.id)
                ? CoachVideoStrings.feedbackSent
                : CoachVideoStrings.awaitingFeedback
            )
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
            .foregroundStyle(
              feedbackVideoIDs.contains(video.id)
                ? Color.MeetPR.success
                : Color.MeetPR.gold500
            )
            Text(CoachStudentFormatting.relativeText(video.displayDate, now: now))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textTertiary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(MeetPRSpacing.space3)
      .meetPRCardSurface(.card)
    }
    .buttonStyle(PressScaleButtonStyle(scale: 0.98))
    .disabled(viewModel.loadingVideoID == video.id)
    .accessibilityIdentifier("coach.detail.video.\(video.id.uuidString)")
  }

  private func videoLabel(_ video: StudentVideo) -> String {
    if let exerciseID = video.planExerciseID,
      let exercise = planDays.flatMap(\.exercises).first(where: { $0.id == exerciseID })
    {
      return exercise.exercise.name
    }
    if let filename = video.filename, !filename.isEmpty {
      return filename
    }
    return CoachVideoStrings.trainingVideo
  }

  private func sectionTitle(_ day: Date) -> String {
    let calendar = CoachFeatureCalendar.calendar
    if CoachFeatureCalendar.isSameDay(day, now, calendar: calendar) {
      return CoachVideoStrings.today
    }
    let yesterday =
      calendar.date(byAdding: .day, value: -1, to: now)
      ?? now
    if CoachFeatureCalendar.isSameDay(day, yesterday, calendar: calendar) {
      return CoachVideoStrings.yesterday
    }
    return day.formatted(
      .dateTime.month(.twoDigits).day(.twoDigits)
        .locale(Locale(identifier: "zh_Hans_CN"))
    )
  }

  private func message(_ title: String, subtitle: String) -> some View {
    ScrollView {
      VStack(spacing: MeetPRSpacing.point10) {
        Image(systemName: "video")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size26))
          .foregroundStyle(Color.MeetPR.success)
        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(subtitle)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textDisabled)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, MeetPRSpacing.point32)
    }
  }

  private func playbackErrorBanner(_ message: String) -> some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Text(message)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
      Spacer()
      Button(CoachVideoStrings.confirmation) {
        viewModel.clearPlaybackError()
      }
      .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
    }
    .foregroundStyle(Color.MeetPR.danger)
    .padding(MeetPRSpacing.space3)
    .meetPRCardSurface(.card)
  }
}

enum CoachVideoStrings {
  static let loadFailed = CoachLocalization.localized("coach.video.loadFailed")
  static let pullToRetry = CoachLocalization.localized("coach.video.pullToRetry")
  static let emptyTitle = CoachLocalization.localized("coach.video.emptyTitle")
  static let emptySubtitle = CoachLocalization.localized("coach.video.emptySubtitle")
  static let feedbackSent = CoachLocalization.localized("coach.video.feedbackSent")
  static let awaitingFeedback = CoachLocalization.localized("coach.video.awaitingFeedback")
  static let trainingVideo = CoachLocalization.localized("coach.video.trainingVideo")
  static let today = CoachLocalization.localized("coach.video.today")
  static let yesterday = CoachLocalization.localized("coach.video.yesterday")
  static let confirmation = CoachLocalization.localized("coach.video.confirmation")
}
