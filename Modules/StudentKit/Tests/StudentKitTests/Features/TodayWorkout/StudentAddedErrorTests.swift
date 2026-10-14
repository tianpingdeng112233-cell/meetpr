import Foundation
import Networking
import Testing

@testable import StudentKit

@MainActor
@Test(arguments: [
  "SET_HAS_ATTACHMENT", "SET_HAS_COACH_FEEDBACK", "SETS_ADHOC_DAY_CONFLICT",
  "SET_NOT_STUDENT_ADDED",
])
func addedErrorsHaveSpecificRecovery(code: String) {
  let error = APIError.httpStatus(409, Data("{\"error\":\"\(code)\"}".utf8))
  #expect(
    TodayWorkoutViewModel.recordingErrorMessage(for: error)
      != StudentStrings.localized(.todayWorkoutViewModelRecordingError004))
}
