import Foundation
import Testing

@testable import RepositoryContracts

@Test("pending video carries its optional set-log link")
func pendingVideoCarriesSetLogLink() {
  let setLogID = UUID()
  let item = PendingVideoItem(
    id: UUID(),
    studentID: UUID(),
    studentDisplayName: "学员",
    setLogID: setLogID,
    uploadedAt: Date(timeIntervalSince1970: 1_780_000_000),
    sizeBytes: 10
  )

  #expect(item.setLogID == setLogID)
}
