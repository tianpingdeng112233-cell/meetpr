import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardFeedbackCard: View {
  let items: [CoachFeedback]
  let viewModel: FeedbackInboxViewModel?
  @Binding var isExpanded: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var previewOpacity = 1.0
  @State private var visibleItemIDs: Set<UUID> = []

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
      if items.isEmpty {
        Text("暂无新反馈")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textMuted)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .frame(minHeight: 44)
          .background(Color.MeetPR.surfaceCard)
          .clipShape(.rect(cornerRadius: 12))
      } else if isExpanded {
        expandedCard
      } else {
        collapsedCard
      }
    }
    .animation(
      reduceMotion ? nil : .timingCurve(0.34, 1.36, 0.64, 1, duration: 0.38),
      value: isExpanded
    )
    .onAppear {
      if isExpanded {
        visibleItemIDs = Set(orderedItems.map(\.id))
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
            .opacity(previewOpacity)
        }

        HStack(spacing: 4) {
          Text("展开全部 \(items.count) 条反馈")
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
    .buttonStyle(.plain)
    .accessibilityLabel("教练反馈，展开全部 \(items.count) 条")
  }

  private var expandedCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: toggle) {
        feedbackHeader(showsCollapseControl: true)
          .padding(.vertical, 13)
          .frame(minHeight: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)

      ForEach(orderedItems.indices, id: \.self) { index in
        let item = orderedItems[index]
        NavigationLink {
          FeedbackDetailView(item: item, viewModel: viewModel)
        } label: {
          feedbackRow(item)
        }
        .buttonStyle(.plain)
        .opacity(visibleItemIDs.contains(item.id) ? 1 : 0)
        .offset(y: visibleItemIDs.contains(item.id) ? 0 : -8)
        .animation(
          reduceMotion
            ? nil
            : .timingCurve(0.22, 0.61, 0.36, 1, duration: 0.2)
              .delay(Double(min(index, 3)) * 0.03 + 0.02),
          value: visibleItemIDs
        )
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
      Text("教练反馈")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      if unreadCount > 0 {
        Text("\(unreadCount) 条未读")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size10, weight: .bold))
          .foregroundStyle(Color.MeetPR.inkOnGold)
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .background(Color.MeetPR.goldText, in: .capsule)
      }

      if showsCollapseControl {
        Spacer(minLength: 0)
        HStack(spacing: 3) {
          Text("收起")
          DashboardChevron(direction: .down)
            .stroke(
              Color.MeetPR.textMuted,
              style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 13, height: 13)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .animation(
              reduceMotion
                ? nil
                : .timingCurve(0.22, 0.61, 0.36, 1, duration: 0.26),
              value: isExpanded
            )
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
      } else if let latestItem {
        Text("· \(weekdayText(for: latestItem))")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textFaint)
      }
    }
  }

  private func feedbackRow(_ item: CoachFeedback) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 7) {
        Text(feedbackLabel(item))
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
          Text("查看")
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
    if reduceMotion {
      isExpanded.toggle()
      visibleItemIDs = isExpanded ? Set(orderedItems.map(\.id)) : []
      previewOpacity = 1
      return
    }

    if isExpanded {
      visibleItemIDs.removeAll()
      withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.28)) {
        isExpanded = false
      }
      previewOpacity = 0
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(90))
        withAnimation(.linear(duration: 0.18)) {
          previewOpacity = 1
        }
      }
      return
    }

    withAnimation(.linear(duration: 0.05)) {
      previewOpacity = 0
    }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(50))
      withAnimation(.timingCurve(0.34, 1.36, 0.64, 1, duration: 0.38)) {
        isExpanded = true
      }
      visibleItemIDs = Set(orderedItems.map(\.id))
    }
  }

  private func feedbackLabel(_ item: CoachFeedback) -> String {
    guard let video = item.video else { return "训练反馈" }
    let exercise = video.exerciseName ?? "训练视频"
    guard let setIndex = video.setIndex else { return exercise }
    return "\(exercise) · 第 \(setIndex) 组"
  }

  private func weekdayText(for item: CoachFeedback) -> String {
    let date = item.dayDate ?? item.postedAt
    let weekday = Calendar.current.component(.weekday, from: date)
    let offset = (weekday + 5) % 7
    return "周\(DashboardTodayPresentation.weekdayLetter(offset))"
  }
}

enum DashboardChevronDirection: Sendable {
  case down
  case right
}

struct DashboardChevron: Shape {
  let direction: DashboardChevronDirection

  func path(in rect: CGRect) -> Path {
    var path = Path()
    switch direction {
    case .down:
      path.move(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.375))
      path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.625))
      path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.375))
    case .right:
      path.move(to: CGPoint(x: rect.width * 0.375, y: rect.height * 0.25))
      path.addLine(to: CGPoint(x: rect.width * 0.625, y: rect.height * 0.5))
      path.addLine(to: CGPoint(x: rect.width * 0.375, y: rect.height * 0.75))
    }
    return path
  }
}
