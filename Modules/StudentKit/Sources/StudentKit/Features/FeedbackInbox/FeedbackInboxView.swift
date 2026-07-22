import CoreModels
import DesignSystem
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let items):
          if items.isEmpty {
            ContentUnavailableView("暂无反馈", systemImage: "bubble.left")
          } else {
            ScrollView {
              VStack(spacing: 12) {
                ForEach(items) { item in
                  NavigationLink {
                    FeedbackDetailView(item: item, viewModel: viewModel)
                      .task { await viewModel.markRead(item) }
                  } label: {
                    FeedbackCard(item: item)
                  }
                  .buttonStyle(.plain)
                }
              }
              .padding()
            }
            .scrollContentBackground(.hidden)
          }
        case .error(let message):
          ContentUnavailableView(
            "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
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
private struct FeedbackCard: View {
  let item: CoachFeedback

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(item.readAt == nil ? Color.MeetPR.brandRed : Color.clear)
        .frame(width: 8, height: 8)
        .padding(.top, 6)
      VStack(alignment: .leading, spacing: 6) {
        Text(item.text)
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(StudentFormatting.dayMonthFormatter.string(from: item.postedAt))
          .font(.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .padding(.top, 2)
    }
    .padding(14)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 12))
  }
}
