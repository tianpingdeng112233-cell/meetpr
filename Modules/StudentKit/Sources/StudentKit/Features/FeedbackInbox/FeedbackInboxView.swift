import CoreModels
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct FeedbackInboxView: View {
  private let studentID: UUID
  private let viewModel: FeedbackInboxViewModel

  public init(studentID: UUID, viewModel: FeedbackInboxViewModel) {
    self.studentID = studentID
    self.viewModel = viewModel
  }

  public var body: some View {
    NavigationStack {
      Group {
        switch viewModel.state {
        case .idle, .loading:
          ProgressView()
        case .loaded(let items):
          List(items) { item in
            NavigationLink {
              FeedbackDetailView(item: item)
                .task { await viewModel.markRead(item) }
            } label: {
              FeedbackRow(item: item)
            }
          }
        case .error(let message):
          ContentUnavailableView(
            "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
        }
      }
      .navigationTitle("反馈")
    }
    .task {
      if viewModel.state == .idle {
        await viewModel.load(studentID: studentID)
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct FeedbackRow: View {
  let item: CoachFeedback

  var body: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(item.readAt == nil ? Color.red : Color.clear)
        .frame(width: 8, height: 8)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.text)
          .lineLimit(2)
        Text(StudentFormatting.dayMonthFormatter.string(from: item.postedAt))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
