import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
extension View {
  func feedbackArchiveCover(
    isPresented: Binding<Bool>,
    studentID: UUID,
    viewModel: FeedbackInboxViewModel?
  ) -> some View {
    modifier(
      FeedbackArchiveCoverModifier(
        isPresented: isPresented,
        studentID: studentID,
        viewModel: viewModel
      )
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct FeedbackArchiveCoverModifier: ViewModifier {
  @Binding var isPresented: Bool
  let studentID: UUID
  let viewModel: FeedbackInboxViewModel?

  @ViewBuilder
  func body(content: Content) -> some View {
    #if os(iOS)
      content.fullScreenCover(isPresented: $isPresented) {
        archive
      }
    #else
      content.sheet(isPresented: $isPresented) {
        archive
      }
    #endif
  }

  @ViewBuilder
  private var archive: some View {
    if let viewModel {
      NavigationStack {
        FeedbackInboxView(studentID: studentID, viewModel: viewModel)
      }
    }
  }
}
