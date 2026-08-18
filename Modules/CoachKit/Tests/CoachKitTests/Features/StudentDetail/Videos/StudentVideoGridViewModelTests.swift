import CoreModels
import Foundation
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func videoGridGroupsByLoggedDayNewestFirstAndFallsBackToCreatedAt() throws {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(secondsFromGMT: 8 * 3_600))
  let base = CoachStudentFeatureFixtures.startDate

  let dayTwoMorning = CoachStudentFeatureFixtures.video(
    id: UUID(uuidString: "02900000-0000-0000-0000-000000001001")!,
    createdAt: base.addingTimeInterval(86_400 + 5 * 3_600),
    loggedAt: base.addingTimeInterval(86_400 + 3_600)
  )
  let dayTwoEvening = CoachStudentFeatureFixtures.video(
    id: UUID(uuidString: "02900000-0000-0000-0000-000000001002")!,
    createdAt: base.addingTimeInterval(86_400 + 13 * 3_600),
    loggedAt: base.addingTimeInterval(86_400 + 12 * 3_600)
  )
  // Unlinked upload: no loggedAt, must group by its createdAt day (day 1).
  let unlinkedDayOne = CoachStudentFeatureFixtures.video(
    id: UUID(uuidString: "02900000-0000-0000-0000-000000001003")!,
    createdAt: base.addingTimeInterval(2 * 3_600),
    loggedAt: nil
  )

  let sections = StudentVideoGridViewModel.makeSections(
    videos: [dayTwoMorning, unlinkedDayOne, dayTwoEvening],
    calendar: calendar
  )

  #expect(sections.count == 2)
  // Newest day first; within a day newest video first.
  #expect(sections[0].videos.map(\.id) == [dayTwoEvening.id, dayTwoMorning.id])
  #expect(sections[1].videos.map(\.id) == [unlinkedDayOne.id])
  #expect(sections[0].day == calendar.startOfDay(for: dayTwoMorning.displayDate))
  #expect(sections[1].day == calendar.startOfDay(for: unlinkedDayOne.createdAt))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func videoGridPlayExchangesIDForPresignedURL() async throws {
  let video = CoachStudentFeatureFixtures.video()
  let url = try #require(URL(string: "https://oss.example.com/play/abc?expires=900"))
  let viewModel = StudentVideoGridViewModel(
    repository: StubCoachStudentVideoRepository(
      videos: [video],
      playbackURLs: [video.id: url]
    )
  )

  await viewModel.play(video)

  #expect(viewModel.playbackItem == StudentVideoPlaybackItem(id: video.id, url: url))
  #expect(viewModel.playbackError == nil)
  #expect(viewModel.loadingVideoID == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func videoGridPlayFailureShowsRetryableErrorWithoutPresenting() async {
  let video = CoachStudentFeatureFixtures.video()
  let viewModel = StudentVideoGridViewModel(
    repository: StubCoachStudentVideoRepository(
      videos: [video],
      playbackError: CoachFeatureTestError()
    )
  )

  await viewModel.play(video)

  #expect(viewModel.playbackItem == nil)
  #expect(viewModel.playbackError == CoachStudentDetailStrings.text("coach.video.error.playback"))
  #expect(viewModel.loadingVideoID == nil)

  viewModel.clearPlaybackError()
  #expect(viewModel.playbackError == nil)
}
