import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

/// Covers camera return while a set has not received its canonical server ID.
@MainActor
struct CameraReturnDuringPersistenceTests {
  @Test(arguments: [false, true])
  func singleSetCameraReturnDuringSaveKeepsVideo(overlapsSave: Bool) async throws {
    let targetRow = 0
    let fixture = CameraPersistenceFixture(setCount: 1)
    let upload = VideoUploadHarness()
    defer { try? FileManager.default.removeItem(at: upload.filesDirectory) }
    await fixture.load()
    let targetID = try #require(fixture.workout.currentDrafts?[targetRow].id)
    let source = try makeTemporaryVideoSource()
    defer { try? FileManager.default.removeItem(at: source) }
    await fixture.logs.pauseNextWrite()
    let save = Task { await fixture.workout.commitSet(rowIndex: targetRow) }
    try await waitUntilOnMain { await fixture.logs.isWritePaused }
    if !overlapsSave {
      await fixture.logs.releaseWrite()
      #expect(await save.value)
    }
    // Same public-call sequence as attachDirectCameraVideo: look up the stable
    // camera target, resolve a canonical set ID, then attach the captured file.
    var callbackStarted = false
    let camera = Task { @MainActor in
      let row = try #require(fixture.workout.currentDrafts?.firstIndex { $0.id == targetID })
      let liveDraft = try #require(fixture.workout.currentDrafts?[row])
      callbackStarted = true
      let setID: UUID?
      if let loggedID = liveDraft.loggedSetID {
        setID = loggedID
      } else {
        setID = await fixture.workout.ensureLoggedSetID(rowIndex: row)
      }
      guard let setID else { return }
      #expect(setID == fixture.logs.canonicalIDs[targetRow])
      let attached = try await upload.manager.enqueue(
        sourceURL: source, setLogID: setID, studentID: fixture.studentID)
      _ = try await waitForStatus(upload.repository, id: attached.id, oneOf: [.uploaded])
    }
    try await waitUntilOnMain { callbackStarted }
    await fixture.logs.releaseWrite()
    #expect(await save.value)
    try await camera.value
    #expect(fixture.workout.currentDrafts?[targetRow].completed == true)
    let rows = try fixture.rows(
      local: await upload.manager.attachments(studentID: fixture.studentID))
    #expect(rows[targetRow].video != nil)

  }

  @Test(arguments: [0, 2], [false, true])
  func cameraReturnOverlappingSetSaveKeepsAllThreeVideos(
    targetRow: Int, overlapsSave: Bool
  ) async throws {
    let fixture = CameraPersistenceFixture()
    let upload = VideoUploadHarness()
    defer { try? FileManager.default.removeItem(at: upload.filesDirectory) }
    await fixture.load()
    for row in 0..<3 where row != targetRow {
      let setID = try #require(await fixture.workout.ensureLoggedSetID(rowIndex: row))
      let item = try await upload.manager.enqueue(
        sourceURL: makeTemporaryVideoSource(), setLogID: setID, studentID: fixture.studentID)
      _ = try await waitForStatus(upload.repository, id: item.id, oneOf: [.uploaded])
      #expect(await fixture.workout.commitSet(rowIndex: row))
    }
    let targetID = try #require(fixture.workout.currentDrafts?[targetRow].id)
    let source = try makeTemporaryVideoSource()
    defer { try? FileManager.default.removeItem(at: source) }
    await fixture.logs.pauseNextWrite()
    let save = Task { await fixture.workout.commitSet(rowIndex: targetRow) }
    try await waitUntilOnMain { await fixture.logs.isWritePaused }
    if !overlapsSave {
      await fixture.logs.releaseWrite()
      #expect(await save.value)
    }
    // Same public-call sequence as attachDirectCameraVideo: look up the stable
    // camera target, resolve a canonical set ID, then attach the captured file.
    var callbackStarted = false
    let camera = Task { @MainActor in
      let row = try #require(fixture.workout.currentDrafts?.firstIndex { $0.id == targetID })
      let liveDraft = try #require(fixture.workout.currentDrafts?[row])
      callbackStarted = true
      let setID: UUID?
      if let loggedID = liveDraft.loggedSetID {
        setID = loggedID
      } else {
        setID = await fixture.workout.ensureLoggedSetID(rowIndex: row)
      }
      guard let setID else { return }
      #expect(setID == fixture.logs.canonicalIDs[targetRow])
      let attached = try await upload.manager.enqueue(
        sourceURL: source, setLogID: setID, studentID: fixture.studentID)
      _ = try await waitForStatus(upload.repository, id: attached.id, oneOf: [.uploaded])
    }
    try await waitUntilOnMain { callbackStarted }
    await fixture.logs.releaseWrite()
    #expect(await save.value)
    try await camera.value
    #expect(fixture.workout.currentDrafts?[targetRow].completed == true)
    #expect(await fixture.workout.completeCurrentDay())
    await fixture.load()
    let rows = try fixture.rows(
      local: await upload.manager.attachments(studentID: fixture.studentID))
    #expect(rows.map { $0.video != nil } == [true, true, true])
  }

}

extension CameraReturnDuringPersistenceTests {
  @Test func cameraReturnDuringOfflineSaveRetainsVideoUntilSetIsSaved() async throws {
    let fixture = CameraPersistenceFixture(setCount: 1)
    let upload = VideoUploadHarness()
    defer { try? FileManager.default.removeItem(at: upload.filesDirectory) }
    let videos = VideoAttachmentViewModel(manager: upload.manager)
    await fixture.load()
    let draftID = try #require(fixture.workout.currentDrafts?.first?.id)
    let source = try makeTemporaryVideoSource()
    defer { try? FileManager.default.removeItem(at: source) }
    await fixture.logs.setOffline(true)
    await videos.attach(
      sourceURL: source, draftID: draftID, studentID: fixture.studentID,
      trainingDate: fixture.day.date,
      resolveSetLogID: { await fixture.workout.ensureLoggedSetID(rowIndex: 0) })
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(await upload.manager.attachments(studentID: fixture.studentID).count == 1)
    let pending = try #require(await upload.manager.attachments(studentID: fixture.studentID).first)
    #expect(pending.pendingDraftID == draftID)
    #expect(pending.status == .failed)
    #expect(videos.pendingRowState(draftID: draftID, trainingDate: fixture.day.date) != nil)
    await fixture.logs.setOffline(false)
    #expect(await fixture.workout.commitSet(rowIndex: 0))
    await videos.resumePendingAttachments(workout: fixture.workout, studentID: fixture.studentID)
    let uploaded = try await waitForStatus(upload.repository, id: pending.id, oneOf: [.uploaded])
    #expect(uploaded.setLogID == fixture.logs.canonicalIDs[0])
    #expect(uploaded.pendingDraftID == nil)
    #expect(try fixture.rows(local: [uploaded])[0].video != nil)

  }

  @Test func cameraReturnAcrossDayChangeRetainsVideoUntilOriginalDayReturns() async throws {
    let fixture = CameraPersistenceFixture(setCount: 1)
    let upload = VideoUploadHarness()
    defer { try? FileManager.default.removeItem(at: upload.filesDirectory) }
    let videos = VideoAttachmentViewModel(manager: upload.manager)
    await fixture.load()
    let draftID = try #require(fixture.workout.currentDrafts?.first?.id)
    let source = try makeTemporaryVideoSource()
    defer { try? FileManager.default.removeItem(at: source) }
    await fixture.logs.pauseNextWrite()
    let camera = Task {
      await videos.attach(
        sourceURL: source, draftID: draftID, studentID: fixture.studentID,
        trainingDate: fixture.day.date,
        resolveSetLogID: { await fixture.workout.ensureLoggedSetID(rowIndex: 0) })
    }
    try await waitUntilOnMain { await fixture.logs.isWritePaused }
    await fixture.workout.load(dayID: fixture.otherDay.id, studentID: fixture.studentID)
    await fixture.logs.releaseWrite()
    await camera.value
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(await upload.manager.attachments(studentID: fixture.studentID).count == 1)
    let pending = try #require(await upload.manager.attachments(studentID: fixture.studentID).first)
    #expect(pending.pendingDraftID == draftID)
    await videos.resumePendingAttachments(workout: fixture.workout, studentID: fixture.studentID)
    #expect(try await upload.repository.fetch(id: pending.id)?.pendingDraftID == draftID)
    await fixture.load()
    await videos.resumePendingAttachments(workout: fixture.workout, studentID: fixture.studentID)
    let uploaded = try await waitForStatus(upload.repository, id: pending.id, oneOf: [.uploaded])
    #expect(uploaded.setLogID == fixture.logs.canonicalIDs[0])
    #expect(uploaded.trainingDate == fixture.day.date)
    #expect(try fixture.rows(local: [uploaded])[0].video != nil)

  }
}

extension CameraReturnDuringPersistenceTests {
  @Test func pendingCameraVideoSurvivesRestartAndRetentionBeforeBinding() async throws {
    let fixture = CameraPersistenceFixture(setCount: 1)
    let disk = CameraPendingDiskHarness()
    defer { try? FileManager.default.removeItem(at: disk.root) }
    await fixture.load()
    let draftID = try #require(fixture.workout.currentDrafts?.first?.id)
    let source = try makeTemporaryVideoSource()
    let bytes = try Data(contentsOf: source)
    defer { try? FileManager.default.removeItem(at: source) }
    let firstManager = disk.manager(repository: disk.repository(), now: fixture.now)
    let first = VideoAttachmentViewModel(manager: firstManager)
    await fixture.logs.setOffline(true)
    await first.attach(
      sourceURL: source, draftID: draftID, studentID: fixture.studentID,
      trainingDate: fixture.day.date,
      resolveSetLogID: { await fixture.workout.ensureLoggedSetID(rowIndex: 0) })
    let pending = try #require(await firstManager.attachments(studentID: fixture.studentID).first)
    let retained = disk.root.appending(path: "files/\(pending.id).source.mov")
    #expect(try Data(contentsOf: retained) == bytes)
    // Simulate the picker/recorder temporary directory disappearing on restart.
    try FileManager.default.removeItem(at: source)
    let repository = disk.repository()
    let manager = disk.manager(
      repository: repository, now: fixture.now.addingTimeInterval(90 * 86_400))
    let restarted = VideoAttachmentViewModel(manager: manager)
    await restarted.start(studentID: fixture.studentID)
    #expect(restarted.pendingRowState(draftID: draftID, trainingDate: fixture.day.date) != nil)
    #expect(try Data(contentsOf: retained) == bytes)
    await manager.retry(attachmentID: pending.id)
    #expect(try await repository.fetch(id: pending.id)?.remoteAttachmentID == nil)
    await fixture.logs.setOffline(false)
    #expect(await fixture.workout.commitSet(rowIndex: 0))
    await restarted.resumePendingAttachments(workout: fixture.workout, studentID: fixture.studentID)
    let uploaded = try await waitForStatus(repository, id: pending.id, oneOf: [.uploaded])
    #expect(uploaded.setLogID == fixture.logs.canonicalIDs[0])
    #expect(uploaded.pendingDraftID == nil)
  }
}

extension CameraReturnDuringPersistenceTests {
  @Test func extraSetCameraVideoRebindsAfterDraftIdentityChangesOnReload() async throws {
    let fixture = CameraPersistenceFixture(setCount: 1)
    let upload = VideoUploadHarness()
    defer { try? FileManager.default.removeItem(at: upload.filesDirectory) }
    let videos = VideoAttachmentViewModel(manager: upload.manager)
    await fixture.load()
    let exercise = try #require(fixture.day.exercises.first)
    fixture.workout.addExtraSet(exerciseID: exercise.id)
    let extra = try #require(fixture.workout.currentDrafts?.last)
    #expect(extra.isExtra)
    let source = try makeTemporaryVideoSource()
    defer { try? FileManager.default.removeItem(at: source) }
    await fixture.logs.pauseNextWrite()
    let camera = Task {
      await videos.attach(
        sourceURL: source, draftID: extra.id, studentID: fixture.studentID,
        trainingDate: fixture.day.date, slot: extra.pendingVideoSlot,
        resolveSetLogID: {
          await fixture.workout.resolveVideoSetLogID(
            draftID: extra.id, trainingDate: fixture.day.date)
        })
    }
    try await waitUntilOnMain { await fixture.logs.isWritePaused }
    await fixture.workout.load(dayID: fixture.otherDay.id, studentID: fixture.studentID)
    await fixture.logs.releaseWrite()
    await camera.value
    let pending = try #require(await upload.manager.attachments(studentID: fixture.studentID).first)
    let frozenNow = fixture.now
    let reloadedWorkout = TodayWorkoutViewModel(
      plans: fixture.plans, logs: fixture.logs, now: { frozenNow })
    await reloadedWorkout.load(dayID: fixture.day.id, studentID: fixture.studentID)
    let restored = try #require(reloadedWorkout.currentDrafts?.last)
    #expect(restored.id != extra.id)
    #expect(
      videos.pendingRowState(
        draftID: restored.id, trainingDate: fixture.day.date, slot: restored.pendingVideoSlot)
        != nil)
    await videos.resumePendingAttachments(workout: reloadedWorkout, studentID: fixture.studentID)
    #expect(try await upload.repository.fetch(id: pending.id)?.pendingDraftID == nil)
    #expect(
      try await upload.repository.fetch(id: pending.id)?.setLogID == fixture.logs.canonicalIDs[1])
  }
}

extension CameraReturnDuringPersistenceTests {
  @Test func successfulCameraHandoffReleasesOnlyTemporaryCopy() async throws {
    let fixture = CameraPersistenceFixture(setCount: 1)
    let upload = VideoUploadHarness()
    defer { try? FileManager.default.removeItem(at: upload.filesDirectory) }
    let videos = VideoAttachmentViewModel(manager: upload.manager)
    await fixture.load()
    let draft = try #require(fixture.workout.currentDrafts?.first)
    let source = try makeTemporaryVideoSource()
    defer { try? FileManager.default.removeItem(at: source) }
    await videos.attach(
      sourceURL: source, draftID: draft.id, studentID: fixture.studentID,
      trainingDate: fixture.day.date,
      resolveSetLogID: {
        await fixture.workout.resolveVideoSetLogID(
          draftID: draft.id, trainingDate: fixture.day.date)
      })
    #expect(!FileManager.default.fileExists(atPath: source.path))
    let record = try #require(await upload.manager.attachments(studentID: fixture.studentID).first)
    let uploaded = try await waitForStatus(upload.repository, id: record.id, oneOf: [.uploaded])
    #expect(uploaded.setLogID == fixture.logs.canonicalIDs[0])
    let filename = try #require(uploaded.localFileName)
    #expect(
      FileManager.default.fileExists(atPath: upload.filesDirectory.appending(path: filename).path))
  }
}
