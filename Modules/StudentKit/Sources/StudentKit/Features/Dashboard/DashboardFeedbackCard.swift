import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardFeedbackCard: View {
  let items: [CoachFeedback]
  let pending: DashboardPendingFeedbackPresentation?
  let coachName: String
  let viewModel: FeedbackInboxViewModel?
  @Binding var isExpanded: Bool

  private var orderedItems: [CoachFeedback] {
    items.sorted { $0.postedAt > $1.postedAt }
  }

  private var unreadCount: Int {
    items.filter { $0.readAt == nil }.count
  }

  private var latestItem: CoachFeedback? {
    orderedItems.first(where: { $0.readAt == nil }) ?? orderedItems.first
  }

  var body: some View {
    Group {
      if let pending {
        DashboardPendingFeedbackCard(
          pending: pending,
          coachName: coachName
        )
      } else if !items.isEmpty {
        if isExpanded {
          expandedCard
        } else {
          collapsedCard
        }
      } else if viewModel?.isLoadedEmpty == true {
        DashboardNoFeedbackCard()
      }
    }
  }

  private var collapsedCard: some View {
    Button(action: toggle) {
      VStack(alignment: .leading, spacing: 0) {
        feedbackHeader(showsCollapseControl: false)

        if let latestItem {
          Text(latestItem.text)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .lineSpacing(4)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 7)
        }

        HStack(spacing: 4) {
          Text(StudentStrings.replacing(.dashboardFeedbackCard001, values: ["\(items.count)"]))
          DashboardChevron(direction: .down)
            .stroke(
              Color.MeetPR.textMuted,
              style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 13, height: 13)
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
        .padding(.top, 9)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surfaceCard)
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(Color.MeetPR.gold500)
          .frame(width: 3)
      }
      .clipShape(.rect(cornerRadius: 12))
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.MeetPR.bgStack)
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.MeetPR.surfaceKey, lineWidth: 1)
          }
          .padding(.horizontal, 7)
          .offset(y: 5)
      }
      .background {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.MeetPR.bgInset)
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.MeetPR.surfaceKey, lineWidth: 1)
          }
          .padding(.horizontal, 14)
          .offset(y: 11)
      }
      .padding(.bottom, 11)
      .contentShape(.rect)
    }
    .accessibilityLabel(
      StudentStrings.replacing(.dashboardFeedbackCard002, values: ["\(items.count)"]))
  }

  private var expandedCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: toggle) {
        feedbackHeader(showsCollapseControl: true)
          .padding(.vertical, 13)
          .frame(minHeight: 44)
          .contentShape(.rect)
      }

      ForEach(orderedItems.indices, id: \.self) { index in
        let item = orderedItems[index]
        NavigationLink {
          FeedbackDetailView(item: item, viewModel: viewModel)
        } label: {
          feedbackRow(item)
        }
      }
    }
    .padding(.horizontal, 15)
    .padding(.bottom, 4)
    .background(Color.MeetPR.surfaceCard)
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(Color.MeetPR.gold500)
        .frame(width: 3)
    }
    .clipShape(.rect(cornerRadius: 12))
  }
}

extension DashboardFeedbackCard {
  private func feedbackHeader(showsCollapseControl: Bool) -> some View {
    HStack(spacing: 7) {
      Circle()
        .fill(Color.MeetPR.gold500)
        .frame(width: 7, height: 7)
      Text(StudentStrings.localized(.dashboardFeedbackCard003))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      if unreadCount > 0 {
        Text(StudentStrings.replacing(.dashboardFeedbackCard004, values: ["\(unreadCount)"]))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size10, weight: .bold))
          .foregroundStyle(Color.MeetPR.inkOnGold)
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .background(Color.MeetPR.goldText, in: .capsule)
      }

      if showsCollapseControl {
        Spacer(minLength: 0)
        HStack(spacing: 3) {
          Text(StudentStrings.localized(.dashboardFeedbackCard005))
          DashboardChevron(direction: .down)
            .stroke(
              Color.MeetPR.textMuted,
              style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 13, height: 13)
            // Expanded header: same chevron flipped, no animation (spec 082 §A.6).
            .rotationEffect(.degrees(180))
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
      } else if let latestItem {
        Text("· \(DashboardFeedbackText.weekday(for: latestItem))")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textFaint)
      }
    }
  }

  private func feedbackRow(_ item: CoachFeedback) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 7) {
        Text(DashboardFeedbackText.label(for: item))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .lineLimit(1)
        if item.readAt == nil {
          Circle()
            .fill(Color.MeetPR.gold500)
            .frame(width: 6, height: 6)
        }
        Spacer(minLength: 0)
        HStack(spacing: 2) {
          Text(StudentStrings.localized(.dashboardFeedbackCard006))
          DashboardChevron(direction: .right)
            .stroke(
              Color.MeetPR.textMuted,
              style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 12, height: 12)
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      }
      Text(item.text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 10)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderSubtle)
        .frame(height: 1)
    }
  }

  private func toggle() {
    isExpanded.toggle()
  }

}
