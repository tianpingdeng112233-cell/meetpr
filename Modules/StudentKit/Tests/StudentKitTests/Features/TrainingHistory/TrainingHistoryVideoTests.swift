import CoreModels
import Foundation
import Testing

@testable import StudentKit

struct TrainingHistoryVideoTests {
  @Test func videoSpaceBelongsOnlyToTheBlockContainingTheVideoOrUpload() {
    let first = UUID()
    let second = UUID()
    let unrelated = UUID()
    let video = StudentVideo(
      id: UUID(), setLogID: second, planExerciseID: nil, contentType: "video/mp4",
      sizeBytes: 100, filename: nil, createdAt: .now, loggedAt: nil)
    #expect(
      TrainingHistoryVideoPresentation.reservesVideoSpace(
        setLogIDs: [first, second, nil], videos: [video], local: []))
    #expect(
      !TrainingHistoryVideoPresentation.reservesVideoSpace(
        setLogIDs: [unrelated, nil], videos: [video], local: []))
    #expect(
      !TrainingHistoryVideoPresentation.reservesVideoSpace(
        setLogIDs: [first, second], videos: [], local: []))
    for status in [VideoAttachment.Status.pending, .uploading, .failed, .uploaded] {
      let upload = VideoAttachment(
        id: UUID(), setLogID: second, studentID: UUID(), status: status,
        contentType: "video/mp4", durationSeconds: 8, sizeBytes: 100,
        localFileName: "clip.mp4", recordedAt: .now)
      #expect(
        TrainingHistoryVideoPresentation.reservesVideoSpace(
          setLogIDs: [first, second], videos: [], local: [upload]))
      #expect(
        !TrainingHistoryVideoPresentation.reservesVideoSpace(
          setLogIDs: [unrelated, nil], videos: [], local: [upload]))
    }
  }

  @Test func overlappingVideoTargetsChooseTheNearestIcon() {
    let regions = [
      1: CGRect(x: 0, y: 0, width: 44, height: 44),
      2: CGRect(x: 0, y: 20, width: 44, height: 44),
    ]
    #expect(
      TrainingHistoryVideoPresentation.playbackNumber(at: CGPoint(x: 22, y: 22), in: regions) == 1)
    #expect(
      TrainingHistoryVideoPresentation.playbackNumber(at: CGPoint(x: 22, y: 42), in: regions) == 2)
    #expect(
      TrainingHistoryVideoPresentation.playbackNumber(at: CGPoint(x: 1, y: 1), in: regions) == 1)
    #expect(
      TrainingHistoryVideoPresentation.playbackNumber(at: CGPoint(x: 43, y: 63), in: regions) == 2)
    #expect(
      TrainingHistoryVideoPresentation.playbackNumber(at: CGPoint(x: 50, y: 22), in: regions) == nil
    )
    #expect(
      TrainingHistoryVideoPresentation.playbackNumber(at: CGPoint(x: 22, y: 80), in: regions) == nil
    )
  }

  @Test func historyUsesActualLogIDForExtraAndStudentAddedSets() {
    let setID = UUID()
    let video = StudentVideo(
      id: UUID(), setLogID: setID, planExerciseID: nil, contentType: "video/mp4",
      sizeBytes: 100, filename: nil, createdAt: .now, loggedAt: nil)
    let presentation = TrainingHistoryVideoPresentation(
      setLogID: setID, setIndex: 5, videos: [video], local: [])
    #expect(presentation.video == .remote(video.id))
    #expect(presentation.number == 6)
    #expect(
      TrainingHistoryVideoPresentation(
        setLogID: nil, setIndex: 0, videos: [video], local: []
      ).video == nil)
  }
}
