import CoreModels
import Foundation
import Testing

@testable import AppShell

@Test(arguments: [UserRole.coach, .selfTrainStudent])
func otherRolesStillRequestNotificationPermissionOnActivation(role: UserRole) {
  var state = PushRegistrationStateMachine()
  _ = state.beginAuthenticatedSession(role: role)
  #expect(state.actionsForActivation(authorization: .notDetermined) == [.requestAuthorization])
  #expect(state.actionsForActivation(authorization: .notDetermined).isEmpty)
}

@Test func authorizedCoachedStudentStillRegistersAndUploadsDeviceToken() throws {
  var state = PushRegistrationStateMachine()
  _ = state.beginAuthenticatedSession(role: .coachedStudent)
  #expect(state.actionsForActivation(authorization: .allowed) == [.registerForRemoteNotifications])
  let action = try #require(state.receivedDeviceToken("00ff").first)
  guard case .upload(let key) = action else {
    Issue.record("Expected authorized student's device token upload")
    return
  }
  #expect(key.token == "00ff")
}

@Test func reminderCannotRequestWithoutAnAuthenticatedSession() {
  var state = PushRegistrationStateMachine()
  #expect(state.actionsForReminder(authorization: .notDetermined).isEmpty)
}

@Test func coachedStudentWaitsForAnExplicitNotificationRequest() {
  var state = PushRegistrationStateMachine()
  _ = state.beginAuthenticatedSession(role: .coachedStudent)
  #expect(state.actionsForActivation(authorization: .notDetermined).isEmpty)
}

@Test func coachedStudentCanRequestNotificationsOnceFromAReminderButton() {
  var state = PushRegistrationStateMachine()
  _ = state.beginAuthenticatedSession(role: .coachedStudent)
  #expect(state.actionsForReminder(authorization: .notDetermined) == [.requestAuthorization])
  #expect(state.actionsForReminder(authorization: .notDetermined).isEmpty)
  #expect(state.authorizationResolved(granted: true) == [.registerForRemoteNotifications])
  #expect(state.actionsForReminder(authorization: .denied).isEmpty)
}

@Test func deniedAuthorizationDoesNotRequestAgain() {
  var state = PushRegistrationStateMachine()
  let beganSession = state.beginAuthenticatedSession()
  #expect(beganSession)
  #expect(state.actionsForActivation(authorization: .notDetermined) == [.requestAuthorization])
  #expect(state.authorizationResolved(granted: false).isEmpty)
  #expect(state.actionsForActivation(authorization: .denied).isEmpty)
}

@Test func failedUploadRetriesOnNextActivation() throws {
  var state = PushRegistrationStateMachine()
  let beganSession = state.beginAuthenticatedSession()
  #expect(beganSession)
  #expect(
    state.actionsForActivation(authorization: .allowed)
      == [.registerForRemoteNotifications]
  )

  let upload = try #require(state.receivedDeviceToken("00ff").first)
  guard case .upload(let key) = upload else {
    Issue.record("Expected an upload action")
    return
  }
  state.uploadFinished(key, succeeded: false)

  #expect(state.actionsForActivation(authorization: .allowed) == [.upload(key)])
}

@Test func reloginUploadsAnUnchangedTokenForTheNewSession() throws {
  var state = PushRegistrationStateMachine()
  let beganFirstSession = state.beginAuthenticatedSession()
  #expect(beganFirstSession)
  _ = state.actionsForActivation(authorization: .allowed)
  let firstAction = try #require(state.receivedDeviceToken("abcd").first)
  guard case .upload(let firstKey) = firstAction else {
    Issue.record("Expected the first upload action")
    return
  }
  state.uploadFinished(firstKey, succeeded: true)

  state.endAuthenticatedSession()
  let beganSecondSession = state.beginAuthenticatedSession()
  #expect(beganSecondSession)
  let actions = state.actionsForActivation(authorization: .allowed)
  #expect(actions.first == .registerForRemoteNotifications)
  guard actions.count == 2, case .upload(let secondKey) = actions[1] else {
    Issue.record("Expected registration followed by a second-session upload")
    return
  }
  #expect(secondKey.token == firstKey.token)
  #expect(secondKey.sessionID != firstKey.sessionID)
}

@Test func changedDeviceTokenUploadsWithinTheSameSession() throws {
  var state = PushRegistrationStateMachine()
  let beganSession = state.beginAuthenticatedSession()
  #expect(beganSession)
  _ = state.actionsForActivation(authorization: .allowed)
  let firstAction = try #require(state.receivedDeviceToken("aaaa").first)
  guard case .upload(let firstKey) = firstAction else {
    Issue.record("Expected an upload action")
    return
  }
  state.uploadFinished(firstKey, succeeded: true)

  let changedAction = try #require(state.receivedDeviceToken("bbbb").first)
  guard case .upload(let changedKey) = changedAction else {
    Issue.record("Expected the changed token to upload")
    return
  }
  #expect(changedKey.sessionID == firstKey.sessionID)
  #expect(changedKey.token == "bbbb")
}

@Test func deviceTokenConvertsToLowercaseTwoDigitHex() {
  #expect(
    DeviceTokenHex.string(from: Data([0x00, 0x01, 0x0f, 0x10, 0xab, 0xff])) == "00010f10abff")
}
