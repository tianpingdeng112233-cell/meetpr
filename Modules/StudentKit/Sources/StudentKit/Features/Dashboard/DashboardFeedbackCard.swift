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

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var previewOpacity = 1.0
  @State private var itemRevealToken = 0
  @State private var arrowProgress = 0.0
  @State private var collapsedHeight: CGFloat = 0
  @State private var expandedHeight: CGFloat = 0
  @State private var heightStart: CGFloat = 0
  @State private var heightEnd: CGFloat = 0
  @State private var heightProgress = 1.0
  @State private var presentedHeight: CGFloat = 0
  @State private var heightIsExpanding = false
  @State private var transitionTarget: Bool?
  @State private var transitionTask: Task<Void, Never>?

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
        ZStack(alignment: .top) {
          collapsedCard
            .opacity(isExpanded ? 0 : 1)
            .allowsHitTesting(!isExpanded)
            .accessibilityHidden(isExpanded)
            .onGeometryChange(for: CGFloat.self) { proxy in
              proxy.size.height
            } action: { height in
              collapsedHeight = height
            }

          if isExpanded || transitionTarget == true {
            expandedCard
              .opacity(isExpanded ? 1 : 0)
              .allowsHitTesting(isExpanded)
              .accessibilityHidden(!isExpanded)
              .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
              } action: { height in
                expandedHeight = height
              }
          }
        }
        .modifier(
          FeedbackHeightEffect(
            progress: reduceMotion ? 1 : heightProgress,
            startHeight: heightStart,
            endHeight: heightEnd,
            steadyHeight: isExpanded ? expandedHeight : collapsedHeight,
            addsOvershoot: heightIsExpanding
          )
        )
        .clipped()
        .onGeometryChange(for: CGFloat.self) { proxy in
          proxy.size.height
        } action: { height in
          presentedHeight = height
        }
      }
    }
    .onAppear {
      arrowProgress = isExpanded ? 1 : 0
    }
    .onChange(of: reduceMotion) { _, newValue in
      guard newValue else { return }
      finishTransitionWithoutAnimation()
    }
    .onDisappear {
      transitionTask?.cancel()
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
        .meetPRRiseIn(
          // motion/02 line 68: 20+i×30ms, 200ms, y=-8→0.
          delay: MeetPRMotion.feedbackItemInitialDelay
            + (Double(index) * MeetPRMotion.feedbackItemStagger),
          duration: MeetPRMotion.feedbackItemDuration,
          offset: MeetPRMotion.feedbackItemOffset,
          initialScaleY: 1,
          trigger: itemRevealToken,
          playsInitially: isExpanded
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
            .modifier(FeedbackArrowEffect(progress: reduceMotion ? 1 : arrowProgress))
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
    transitionTask?.cancel()
    let expands = !(transitionTarget ?? isExpanded)
    transitionTarget = expands
    if reduceMotion {
      finishTransitionWithoutAnimation()
      return
    }
    if expands {
      beginExpansion()
    } else {
      beginCollapse()
    }
  }

  private func beginCollapse() {
    if isExpanded {
      beginHeightTween(
        from: FeedbackHeightTransition.resolvedStartHeight(
          presentedHeight: presentedHeight,
          fallbackHeight: expandedHeight
        ),
        to: collapsedHeight,
        duration: MeetPRMotion.feedbackCollapseDuration,
        addsOvershoot: false
      )
    }
    isExpanded = false
    arrowProgress = 0
    previewOpacity = 0
    transitionTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(MeetPRMotion.feedbackPreviewReturnDelay))
      guard !Task.isCancelled, transitionTarget == false else { return }
      withAnimation(.linear(duration: MeetPRMotion.feedbackPreviewReturnDuration)) {
        previewOpacity = 1
      }
      transitionTarget = nil
    }
  }

  private func beginExpansion() {
    withAnimation(.linear(duration: MeetPRMotion.feedbackPreviewFadeDuration)) {
      previewOpacity = 0
    }
    transitionTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(MeetPRMotion.feedbackPreviewFadeDuration))
      guard !Task.isCancelled, transitionTarget == true else { return }
      beginHeightTween(
        from: FeedbackHeightTransition.resolvedStartHeight(
          presentedHeight: presentedHeight,
          fallbackHeight: collapsedHeight
        ),
        to: expandedHeight,
        duration: MeetPRMotion.feedbackExpandDuration,
        addsOvershoot: true
      )
      isExpanded = true
      itemRevealToken += 1
      arrowProgress = 0
      // motion/02 line 70: a 260ms exact easeOutCubic rotation to 180°.
      withAnimation(.linear(duration: MeetPRMotion.feedbackArrowDuration)) {
        arrowProgress = 1
      }
      transitionTarget = nil
    }
  }

  private func finishTransitionWithoutAnimation() {
    transitionTask?.cancel()
    let expands = transitionTarget ?? isExpanded
    var transaction = Transaction()
    transaction.animation = nil
    withTransaction(transaction) {
      isExpanded = expands
      heightProgress = 1
      heightStart = expands ? collapsedHeight : expandedHeight
      heightEnd = expands ? expandedHeight : collapsedHeight
      heightIsExpanding = false
      arrowProgress = expands ? 1 : 0
      previewOpacity = 1
      transitionTarget = nil
    }
  }

  private func beginHeightTween(
    from start: CGFloat,
    to end: CGFloat,
    duration: TimeInterval,
    addsOvershoot: Bool
  ) {
    var transaction = Transaction()
    transaction.animation = nil
    withTransaction(transaction) {
      heightStart = start
      heightEnd = end
      heightIsExpanding = addsOvershoot
      heightProgress = 0
    }
    // motion/02 lines 71 and 75: a linear clock feeds exact easeOutCubic;
    // only expansion adds the p>.62 three-point sine overshoot.
    withAnimation(.linear(duration: duration)) {
      heightProgress = 1
    }
  }

}
