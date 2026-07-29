// swiftlint:disable file_length
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TodayWorkoutScreen<CalendarContent: View>: View {
  enum Content {
    case loading
    case workout(TodayWorkoutPresentation)
    case noPlan
    case rest
    case error(String)
  }

  let content: Content
  let weekCode: String
  let selectedDate: Date
  let isEditable: Bool
  let reviewCompleted: Bool
  let unreadCount: Int
  let showsNotifications: Bool
  let coachName: String
  let showsAskCoach: Bool
  let isPreparingAskCoach: Bool
  let namespace: Namespace.ID
  let isLaunchTargetHidden: Bool
  let launchHeroRevealToken: Int
  @Binding var collapsedExercises: [UUID: Bool]
  let calendarContent: CalendarContent
  let onRefresh: () -> Void
  let onReadiness: () -> Void
  let onNotifications: () -> Void
  let onMessageCoach: () -> Void
  let onAskCoach: () -> Void
  let onHeroFrameChange: (CGRect) -> Void
  let onStart: () -> Void
  let onEdit: (TodayWorkoutPresentation.Row) -> Void
  let onVideoAction: (TodayWorkoutPresentation.Row) -> Void
  let onComplete: () -> Void
  let onShowReview: () -> Void

  @State private var calendarScrollState = TrainingCalendarScrollState(isOpen: true)
  @State private var contentHeight: CGFloat = 0
  @State private var viewportHeight: CGFloat = 0

  @ViewBuilder
  var body: some View {
    if #available(iOS 18.0, macOS 15.0, *) {
      geometryTrackedScrollView
        .trainingCalendarCollapsedOverlay(
          isOpen: calendarScrollState.isOpen,
          date: selectedDate
        )
    } else {
      legacyGeometryTrackedScrollView
        .trainingCalendarCollapsedOverlay(
          isOpen: calendarScrollState.isOpen,
          date: selectedDate
        )
    }
  }

  private var trainingScrollView: some View {
    ScrollView {
      trainingScrollContent
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
  }

  private var trainingScrollContent: some View {
    LazyVStack(alignment: .leading, spacing: MeetPRSpacing.point13) {
      TodayWorkoutHeader(
        weekCode: weekCode,
        unreadCount: unreadCount,
        showsNotifications: showsNotifications,
        onRefresh: onRefresh,
        onReadiness: onReadiness,
        onNotifications: onNotifications
      )

      // Closed state must be mutually exclusive with the full calendar
      // (mockup trainCalOpen/Closed). The layout slot is retained so the
      // scroll offset never feeds back into the open/close state machine —
      // SwiftUI has no browser-style scroll anchoring; the true in-flow
      // collapse with offset compensation is a W5 motion item.
      calendarContent
        .opacity(calendarScrollState.isOpen ? 1 : 0)
        .allowsHitTesting(calendarScrollState.isOpen)
        .accessibilityElement(
          children: calendarScrollState.isOpen ? .contain : .ignore
        )
        .accessibilityHidden(!calendarScrollState.isOpen)
      // The legend is stateless, so the collapsed state removes it outright —
      // runtime snapshots collect static text past accessibility hiding.
      if calendarScrollState.isOpen {
        TrainingCalendarLegend()
      }
      screenContent
    }
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.top, MeetPRSpacing.point6)
    .padding(.bottom, MeetPRSpacing.point28)
  }

  @available(iOS 18.0, macOS 15.0, *)
  private var geometryTrackedScrollView: some View {
    trainingScrollView
      .onScrollGeometryChange(for: TrainingScrollMetrics.self) { geometry in
        TrainingScrollMetrics(
          offset: max(0, geometry.contentOffset.y + geometry.contentInsets.top),
          contentSlack: max(0, geometry.contentSize.height - geometry.containerSize.height)
        )
      } action: { _, metrics in
        updateCalendarScrollState(using: metrics)
      }
  }

  private var legacyGeometryTrackedScrollView: some View {
    GeometryReader { viewport in
      ScrollView {
        trainingScrollContent
          .background {
            GeometryReader { contentProxy in
              Color.clear.preference(
                key: TrainingContentHeightKey.self,
                value: contentProxy.size.height
              )
            }
          }
          .background {
            GeometryReader { offsetProxy in
              Color.clear.preference(
                key: TrainingScrollOffsetKey.self,
                value: offsetProxy.frame(in: .named("training-scroll")).minY
              )
            }
          }
      }
      .scrollIndicators(.hidden)
      .background(Color.MeetPR.bgBase)
      .coordinateSpace(name: "training-scroll")
      .onAppear { viewportHeight = viewport.size.height }
      .onChange(of: viewport.size.height) { _, height in viewportHeight = height }
      .onPreferenceChange(TrainingContentHeightKey.self) { contentHeight = $0 }
      .onPreferenceChange(TrainingScrollOffsetKey.self) { minimumY in
        updateCalendarScrollState(
          using: TrainingScrollMetrics(
            offset: max(0, -minimumY),
            contentSlack: max(0, contentHeight - viewportHeight)
          )
        )
      }
    }
  }

  private func updateCalendarScrollState(using metrics: TrainingScrollMetrics) {
    let next = calendarScrollState.updating(
      offset: metrics.offset,
      contentSlack: metrics.contentSlack
    )
    if next != calendarScrollState {
      calendarScrollState = next
    }
  }

  @ViewBuilder
  private var screenContent: some View {
    if !isEditable {
      TodayWorkoutReadOnlyNotice(date: selectedDate)
    }

    switch content {
    case .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 220)
    case .workout(let presentation):
      TodayWorkoutHero(
        presentation: presentation,
        isEditable: isEditable,
        namespace: namespace,
        isLaunchTargetHidden: isLaunchTargetHidden,
        launchHeroRevealToken: launchHeroRevealToken,
        onFrameChange: onHeroFrameChange,
        onStart: onStart,
        onEdit: onEdit,
        onVideoAction: onVideoAction,
        showsAskCoach: showsAskCoach,
        isPreparingAskCoach: isPreparingAskCoach,
        onAskCoach: onAskCoach
      )

      if presentation.heroMode == .recording {
        TodayWorkoutExerciseList(
          exercises: presentation.exercises,
          collapsedExercises: $collapsedExercises,
          onEdit: onEdit,
          onVideoAction: onVideoAction
        )

        if !presentation.progress.allDone {
          TodayWorkoutRemainingPill(text: presentation.progress.remainingText)
        }
      }

      completionContent(presentation)
    case .rest:
      TodayWorkoutRestCard()
    case .noPlan:
      TodayWorkoutPlanUnavailableCard(
        coachName: coachName,
        onMessageCoach: onMessageCoach
      )
    case .error(let message):
      ContentUnavailableView(
        "加载失败",
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
      .frame(maxWidth: .infinity, minHeight: 220)
    }
  }

  @ViewBuilder
  private func completionContent(_ presentation: TodayWorkoutPresentation) -> some View {
    if presentation.progress.allDone {
      // The hero action row is gone once every set is logged, so the entry has to land here —
      // finishing a session is exactly when a student wants to ask. Full width rather than the
      // hero's square icon: there is no camera control to sit beside.
      if showsAskCoach {
        TodayWorkoutAskCoachWideButton(
          isPreparing: isPreparingAskCoach,
          action: onAskCoach
        )
      }

      if reviewCompleted || !isEditable {
        DayCompletionBanner(totalSets: presentation.exercises.flatMap(\.rows).count) {
          onShowReview()
        }
      } else {
        HoldToCompleteButton(action: onComplete)
      }
    }
  }
}

private struct TodayWorkoutAskCoachWideButton: View {
  let isPreparing: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if isPreparing {
          ProgressView()
            .controlSize(.small)
            .tint(Color.MeetPR.textTertiary)
        } else {
          Label(StudentStrings.askCoach, systemImage: "bubble.left")
        }
      }
      .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .frame(maxWidth: .infinity)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(.plain)
    .disabled(isPreparing)
    .accessibilityIdentifier("todayWorkout.askCoach")
  }
}

private struct TodayWorkoutAskCoachButton: View {
  let isPreparing: Bool
  let action: () -> Void

  var body: some View {
    // Square icon button sized to match the camera control beside it. It lives in the hero
    // action row rather than at the foot of the page: the rest timer pins itself to the bottom
    // the moment a set is logged, and that is exactly when a student wants to ask — the old
    // placement put the entry underneath the bar.
    Button(action: action) {
      Group {
        if isPreparing {
          ProgressView()
            .controlSize(.small)
            .tint(Color.MeetPR.textTertiary)
        } else {
          Image(systemName: "bubble.left")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.MeetPR.textTertiary)
        }
      }
      .frame(width: 52, height: 52)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    }
    .buttonStyle(.plain)
    .disabled(isPreparing)
    .accessibilityLabel(StudentStrings.askCoach)
    .accessibilityIdentifier("todayWorkout.askCoach")
  }
}

/// Design source:
/// `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
/// scene 07, training-content dashed slot.
@available(iOS 17.0, macOS 14.0, *)
private struct TodayWorkoutPlanUnavailableCard: View {
  let coachName: String
  let onMessageCoach: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      TodayWorkoutPlanSkeleton()

      Text("第一周计划还没生效")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("\(coachName)确认你的基线后，这里会出现当天的动作清单——每个动作带组数、重量和示范视频")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textMuted)
        .multilineTextAlignment(.center)
        .lineSpacing(4)
        .frame(maxWidth: 260)
      Button("看看教练发来的消息", action: onMessageCoach)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .padding(.horizontal, MeetPRSpacing.point18)
        .frame(minHeight: 38)
        .overlay {
          Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, MeetPRSpacing.point18)
    .padding(.vertical, MeetPRSpacing.point26)
    .frame(maxWidth: .infinity)
    .background(Color.MeetPR.bgInset)
    .clipShape(.rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TodayWorkoutPlanSkeleton: View {
  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Canvas { context, _ in
        drawSkeletonRow(
          in: &context,
          frame: CGRect(x: 4, y: 4, width: 64, height: 12),
          opacity: 1,
          labelWidth: 18
        )
        drawSkeletonRow(
          in: &context,
          frame: CGRect(x: 4, y: 22, width: 52, height: 12),
          opacity: 0.7,
          labelWidth: 14
        )
        drawSkeletonRow(
          in: &context,
          frame: CGRect(x: 4, y: 40, width: 40, height: 12),
          opacity: 0.4,
          labelWidth: nil
        )
      }
      .frame(width: 72, height: 56)

      Circle()
        .fill(Color.MeetPR.gold500)
        .frame(width: 22, height: 22)
        .overlay {
          Image(systemName: "clock")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size10, weight: .bold))
            .foregroundStyle(Color.MeetPR.inkOnGold)
        }
        .overlay {
          Circle().stroke(Color.MeetPR.bgInset, lineWidth: 2.5)
        }
        .offset(x: 7, y: 3)
    }
    .accessibilityHidden(true)
  }

  private func drawSkeletonRow(
    in context: inout GraphicsContext,
    frame: CGRect,
    opacity: Double,
    labelWidth: CGFloat?
  ) {
    context.stroke(
      Path(roundedRect: frame, cornerRadius: 4),
      with: .color(Color.MeetPR.borderStrong.opacity(opacity)),
      style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
    )
    if let labelWidth {
      context.fill(
        Path(
          roundedRect: CGRect(
            x: frame.minX + 5,
            y: frame.minY + 4,
            width: labelWidth,
            height: 4
          ),
          cornerRadius: 2
        ),
        with: .color(Color.MeetPR.borderStrong.opacity(opacity))
      )
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TodayWorkoutHeader: View {
  let weekCode: String
  let unreadCount: Int
  let showsNotifications: Bool
  let onRefresh: () -> Void
  let onReadiness: () -> Void
  let onNotifications: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point1) {
      MeetPRMark.header
        .frame(width: 97, height: 24, alignment: .leading)

      HStack {
        Text(weekCode)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size20))
          .foregroundStyle(Color.MeetPR.textPrimary)

        Spacer()

        HStack(spacing: MeetPRSpacing.point9) {
          TrainingHeaderButton(accessibilityLabel: "刷新", action: onRefresh) {
            Image(systemName: "arrow.clockwise")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size17, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textSecondary)
          }

          TrainingHeaderButton(accessibilityLabel: "填写今日状态", action: onReadiness) {
            ReadinessIcon()
              .stroke(
                Color.MeetPR.textSecondary,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
              )
          }

          if showsNotifications {
            TrainingHeaderButton(accessibilityLabel: "消息与通知", action: onNotifications) {
              MessageIcon()
                .stroke(
                  Color.MeetPR.textPrimary,
                  style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
            .overlay(alignment: .topTrailing) {
              if unreadCount > 0 {
                Text(unreadCount > 99 ? "99+" : unreadCount.formatted())
                  .font(.MeetPR.mono(size: MeetPRFontMetrics.size9, weight: .bold))
                  .foregroundStyle(Color.white)
                  .padding(.horizontal, MeetPRSpacing.point3)
                  .frame(minWidth: 16, minHeight: 16)
                  .background(Color.MeetPR.dangerFill, in: .capsule)
                  .offset(x: 2, y: -2)
              }
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct TrainingHeaderButton<Icon: View>: View {
  let accessibilityLabel: String
  let action: () -> Void
  let icon: Icon

  init(
    accessibilityLabel: String,
    action: @escaping () -> Void,
    @ViewBuilder icon: () -> Icon
  ) {
    self.accessibilityLabel = accessibilityLabel
    self.action = action
    self.icon = icon()
  }

  var body: some View {
    Button(action: action) {
      icon
        .frame(width: 18, height: 18)
        .frame(width: MeetPRSpacing.point40, height: MeetPRSpacing.point40)
        .background(Color.MeetPR.surfaceCard, in: .circle)
        .frame(
          width: MeetPRSpacing.minimumHitTarget,
          height: MeetPRSpacing.minimumHitTarget
        )
        .contentShape(.rect)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel(accessibilityLabel)
  }
}

// swiftlint:disable:next type_body_length
private struct TodayWorkoutHero: View {
  let presentation: TodayWorkoutPresentation
  let isEditable: Bool
  let namespace: Namespace.ID
  let isLaunchTargetHidden: Bool
  let launchHeroRevealToken: Int
  let onFrameChange: (CGRect) -> Void
  let onStart: () -> Void
  let onEdit: (TodayWorkoutPresentation.Row) -> Void
  let onVideoAction: (TodayWorkoutPresentation.Row) -> Void
  let showsAskCoach: Bool
  let isPreparingAskCoach: Bool
  let onAskCoach: () -> Void

  var body: some View {
    ZStack(alignment: .leading) {
      Color.MeetPR.bgInset

      LinearGradient(
        colors: [
          Color.MeetPR.gold300,
          Color.MeetPR.gold400,
          Color.MeetPR.gold500,
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(width: MeetPRSpacing.point3)
      .frame(maxHeight: .infinity)

      Group {
        switch presentation.heroMode {
        case .list:
          listHero
        case .recording:
          recordingHero
        }
      }
      .padding(MeetPRSpacing.space4)
      .padding(.leading, MeetPRSpacing.point3)
      .transition(.opacity)
    }
    .clipShape(
      .rect(
        topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 16, topTrailingRadius: 16
      )
    )
    .overlay {
      UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: MeetPRRadius.card,
        topTrailingRadius: MeetPRRadius.card
      )
      .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
    }
    .matchedGeometryEffect(id: "today-workout-hero", in: namespace)
    .opacity(isLaunchTargetHidden ? 0 : 1)
    .onGeometryChange(for: CGRect.self) { proxy in
      proxy.frame(in: .global)
    } action: { frame in
      // The dashboard launch morph targets the auto-start recording hero.
      // Never publish the taller pre-start list hero as a candidate frame.
      if presentation.heroMode == .recording { onFrameChange(frame) }
    }
  }

  private var listHero: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      Text("今日训练")
        .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .padding(.bottom, MeetPRSpacing.space1)

      Text(
        "共 \(presentation.exercises.count) 个动作 · "
          + "\(presentation.exercises.flatMap(\.rows).count) 组"
      )
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textTertiary)
      .padding(.bottom, MeetPRSpacing.point13)

      VStack(spacing: MeetPRSpacing.space2) {
        ForEach(presentation.exercises) { exercise in
          let first = exercise.rows.first?.record
          HStack(spacing: MeetPRSpacing.point11) {
            Text((exercise.stableIndex + 1).formatted())
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
              .foregroundStyle(Color.MeetPR.goldText)
              .frame(width: 22, height: 22)
              .background(Color.MeetPR.goldRGB.opacity(0.12))
              .clipShape(.rect(cornerRadius: MeetPRSpacing.point7))

            Text(exercise.name)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
              .foregroundStyle(Color.MeetPR.textPrimary)

            Spacer(minLength: MeetPRSpacing.space2)

            if let first {
              let weight = first.weight.map { "\(numberText($0))kg" } ?? "—"
              Text(
                "\(weight) × \(first.reps) · "
                  + "\(exercise.rows.count) 组"
              )
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.textTertiary)
            }
          }
          .padding(.horizontal, MeetPRSpacing.point13)
          .padding(.vertical, MeetPRSpacing.point11)
          .background(Color.MeetPR.surfaceCard)
          .overlay {
            RoundedRectangle(cornerRadius: MeetPRRadius.control)
              .stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
          }
          .clipShape(.rect(cornerRadius: MeetPRRadius.control))
        }
      }
      .padding(.bottom, MeetPRSpacing.point14)

      if isEditable {
        GoldCTA(
          "开始第一组",
          sub: nil,
          icon: .none,
          showsShimmer: true,
          action: onStart
        )
      }
    }
  }

  @ViewBuilder
  private var recordingHero: some View {
    if let row = presentation.currentRow,
      let exercise = presentation.exercises.first(where: { $0.id == row.draft.planExerciseID })
    {
      VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
        Text(exercise.name)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .padding(.bottom, MeetPRSpacing.point3)
          .launchHeroRise(index: 0, trigger: launchHeroRevealToken)

        Text(exercise.reference)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.bottom, MeetPRSpacing.point11)
          .launchHeroRise(index: 1, trigger: launchHeroRevealToken)

        HStack(spacing: MeetPRSpacing.space2) {
          Text(presentation.progress.allDone ? "已完成" : "当前")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
            .tracking(0.55)
            .foregroundStyle(
              presentation.progress.allDone
                ? Color.MeetPR.success
                : Color.MeetPR.goldText
            )
            .padding(.horizontal, MeetPRSpacing.point11)
            .padding(.vertical, MeetPRSpacing.point3)
            .background(
              (presentation.progress.allDone
                ? Color.MeetPR.successRGB
                : Color.MeetPR.goldRGB)
                .opacity(0.16),
              in: .capsule
            )

          Text(
            presentation.progress.allDone
              ? "今日全部动作已记录"
              : presentation.progress.positionText
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
          .accessibilityIdentifier("todayWorkout.activeSet.position")
        }
        .padding(.bottom, MeetPRSpacing.point10)
        .launchHeroRise(index: 2, trigger: launchHeroRevealToken)

        HStack(alignment: .bottom, spacing: MeetPRSpacing.point9) {
          Text(row.record.weight.map(numberText) ?? "—")
            .font(.MeetPR.display(size: MeetPRFontMetrics.size54))
            .foregroundStyle(Color.MeetPR.textPrimary)
          if row.record.weight != nil {
            Text("KG")
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size16, weight: .bold))
              .foregroundStyle(Color.MeetPR.textMuted)
              .padding(.bottom, MeetPRSpacing.space2)
          }

          Spacer()

          Text("×\(row.record.reps)")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size20, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .padding(.bottom, MeetPRSpacing.space2)
          Text("次")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textMuted)
            .padding(.bottom, MeetPRSpacing.point9)
        }
        .launchHeroRise(index: 3, trigger: launchHeroRevealToken)

        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space2) {
          Text("目标 RPE")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
            .tracking(0.55)
            .foregroundStyle(Color.MeetPR.textFaint)
          Text(numberText(row.record.rpe))
            .font(.MeetPR.display(size: MeetPRFontMetrics.size20))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("/ 10")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textFaint)
        }
        .padding(.top, MeetPRSpacing.space2)
        .launchHeroRise(index: 4, trigger: launchHeroRevealToken)

        if !exercise.note.isEmpty {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
            Text("教练备注")
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textFaint)
            Text(exercise.note)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.coachNoteText)
              .lineSpacing(MeetPRSpacing.point6)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, MeetPRSpacing.space3)
          .padding(.vertical, MeetPRSpacing.point10)
          .background(Color.MeetPR.bgInset)
          .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
          .padding(.top, MeetPRSpacing.point11)
          .launchHeroRise(index: 5, trigger: launchHeroRevealToken)
        }

        if isEditable && !presentation.progress.allDone {
          HStack(spacing: MeetPRSpacing.point9) {
            GoldCTA(
              "记录此组",
              sub: nil,
              icon: .none,
              action: { onEdit(row) }
            )

            Button {
              onVideoAction(row)
            } label: {
              CameraOutlineIcon()
                .stroke(
                  Color.MeetPR.textTertiary,
                  style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 22, height: 22)
                .frame(width: 52, height: 52)
                .background(Color.MeetPR.surfaceCard)
                .overlay {
                  RoundedRectangle(cornerRadius: MeetPRRadius.control)
                    .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
                }
                .clipShape(.rect(cornerRadius: MeetPRRadius.control))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("记录本组视频")

            if showsAskCoach {
              TodayWorkoutAskCoachButton(
                isPreparing: isPreparingAskCoach,
                action: onAskCoach
              )
            }
          }
          .padding(.top, MeetPRSpacing.point13)
          .launchHeroRise(index: 6, trigger: launchHeroRevealToken)
        }
      }
    }
  }

  private func numberText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

private struct TodayWorkoutExerciseList: View {
  let exercises: [TodayWorkoutPresentation.Exercise]
  @Binding var collapsedExercises: [UUID: Bool]
  let onEdit: (TodayWorkoutPresentation.Row) -> Void
  let onVideoAction: (TodayWorkoutPresentation.Row) -> Void

  var body: some View {
    ForEach(exercises.indices, id: \.self) { index in
      let exercise = exercises[index]
      ExerciseCard(
        exercise: exercise.name,
        meta: exercise.reference,
        note: exercise.note,
        collapsed: collapsedExercises[exercise.id] ?? exercise.allRecorded,
        sets: exercise.rows.map(\.record),
        onToggle: { isOpen in
          collapsedExercises[exercise.id] = !isOpen
        },
        onEditSet: { record in
          guard let row = exercise.rows.first(where: { $0.record.index == record.index }) else {
            return
          }
          onEdit(row)
        },
        onVideoAction: { record in
          guard let row = exercise.rows.first(where: { $0.record.index == record.index }) else {
            return
          }
          onVideoAction(row)
        }
      )
      // motion/04 lines 98-99: after "开始第一组", cards use
      // base=360ms and step=90ms.
      .meetPRRiseIn(
        delay: MeetPRMotion.recordingRevealDelay
          + (Double(index) * MeetPRMotion.recordingRevealStagger)
      )
    }
  }
}

extension View {
  fileprivate func launchHeroRise(index: Int, trigger: Int) -> some View {
    meetPRRiseIn(
      // motion/01 lines 107-109: child delay is i×55ms.
      delay: Double(index) * MeetPRMotion.launchHeroChildStagger,
      duration: MeetPRMotion.launchHeroChildDuration,
      offset: MeetPRMotion.launchHeroChildOffset,
      initialScaleY: 1,
      trigger: trigger,
      playsInitially: false
    )
  }
}

private struct TodayWorkoutRemainingPill: View {
  let text: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      ClockOutlineIcon()
        .stroke(
          Color.MeetPR.textDim,
          style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )
        .frame(width: 15, height: 15)
      Text(text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
    }
    .foregroundStyle(Color.MeetPR.textDim)
    .frame(maxWidth: .infinity)
    .padding(.vertical, MeetPRSpacing.space4)
    .overlay {
      Capsule()
        .stroke(
          Color.MeetPR.borderStrong,
          style: StrokeStyle(lineWidth: 1, dash: [4, 4])
        )
    }
  }
}

private struct HoldToCompleteButton: View {
  let action: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress = 0.0
  @State private var isPressing = false
  @State private var hapticStep = 0
  @State private var hapticTask: Task<Void, Never>?

  var body: some View {
    ZStack {
      Color.MeetPR.holdTrack

      GeometryReader { proxy in
        LinearGradient(
          colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.gold400],
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: proxy.size.width * progress)
        .shadow(color: Color.MeetPR.goldRGB.opacity(0.55), radius: 11)
      }

      HStack(spacing: MeetPRSpacing.point9) {
        ClockOutlineIcon()
          .stroke(
            Color.white,
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
          )
          .frame(width: 17, height: 17)
        Text("长按 · 完成今日训练")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
      }
      .foregroundStyle(Color.white)
      .shadow(color: Color.black.opacity(0.45), radius: 1, y: 1)
    }
    .frame(minHeight: 58)
    .clipShape(.capsule)
    .overlay {
      Capsule().stroke(Color.MeetPR.goldRGB.opacity(0.5), lineWidth: 1)
    }
    .shadow(color: Color.MeetPR.goldRGB.opacity(0.15), radius: 10, y: 4)
    .meetPRShimmer(true)
    .scaleEffect(isPressing ? 0.96 : 1)
    .animation(reduceMotion ? nil : MeetPRMotion.press, value: isPressing)
    .onLongPressGesture(
      minimumDuration: reduceMotion ? 0 : MeetPRMotion.durationHoldComplete,
      maximumDistance: 50,
      perform: complete,
      onPressingChanged: pressingChanged
    )
    .sensoryFeedback(.impact(weight: .light), trigger: hapticStep)
    .accessibilityElement()
    .accessibilityLabel("长按完成今日训练")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { complete() }
    .onDisappear { hapticTask?.cancel() }
  }

  private func pressingChanged(_ pressing: Bool) {
    isPressing = pressing
    hapticTask?.cancel()
    if pressing {
      if reduceMotion {
        progress = 1
        return
      }
      withAnimation(.linear(duration: MeetPRMotion.durationHoldComplete)) {
        progress = 1
      }
      hapticTask = Task { @MainActor in
        for step in 1...7 {
          try? await Task.sleep(
            for: .milliseconds(Int(MeetPRMotion.durationHoldComplete * 1_000 / 7))
          )
          guard !Task.isCancelled, isPressing else { return }
          hapticStep = step
        }
      }
    } else if progress < 1 {
      withAnimation(
        .timingCurve(
          MeetPRMotion.rollX1,
          MeetPRMotion.rollY1,
          MeetPRMotion.rollX2,
          MeetPRMotion.rollY2,
          duration: MeetPRMotion.durationHoldCancel
        )
      ) {
        progress = 0
      }
    }
  }

  private func complete() {
    hapticTask?.cancel()
    isPressing = false
    progress = 1
    action()
  }
}

private struct TodayWorkoutReadOnlyNotice: View {
  let date: Date

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Image(systemName: WorkoutDatePolicy.isPast(date) ? "clock.arrow.circlepath" : "eye")
      Text(WorkoutDatePolicy.isPast(date) ? "历史记录 · 不可修改" : "未到训练日 · 仅预览")
      Spacer()
    }
    .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
    .foregroundStyle(Color.MeetPR.textSecondary)
    .padding(MeetPRSpacing.space3)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
  }
}

private struct TodayWorkoutRestCard: View {
  var body: some View {
    Text("休息日 · 无训练安排")
      .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
      .foregroundStyle(Color.MeetPR.textMuted)
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.space5)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}

private struct TrainingCalendarCollapsedBar: View {
  let date: Date

  var body: some View {
    HStack(spacing: MeetPRSpacing.point9) {
      Text(
        TrainingCalendarText.collapsedDate(for: date)
      )
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
      .foregroundStyle(Color.MeetPR.textPrimary)

      Spacer()

      HStack(spacing: MeetPRSpacing.point3) {
        Text("上滑到顶展开")
        ChevronUpIcon()
          .stroke(
            Color.MeetPR.textDim,
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
          .frame(width: 13, height: 13)
      }
      .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      .foregroundStyle(Color.MeetPR.textDim)
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.point11)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .stroke(Color.MeetPR.surfaceKey, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    .shadow(color: Color.black.opacity(0.35), radius: 8, y: 6)
    .padding(.top, MeetPRSpacing.point6)
    .padding(.bottom, MeetPRSpacing.point3)
  }
}

private struct TrainingScrollMetrics: Equatable {
  let offset: CGFloat
  let contentSlack: CGFloat
}

private struct TrainingScrollOffsetKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct TrainingContentHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

extension View {
  fileprivate func trainingCalendarCollapsedOverlay(
    isOpen: Bool,
    date: Date
  ) -> some View {
    overlay(alignment: .top) {
      if !isOpen {
        TrainingCalendarCollapsedBar(date: date)
          .padding(.horizontal, MeetPRSpacing.pageHorizontal)
          // motion/04 lines 101-107: pillIn is 340ms with exact
          // easeOutCubic, y=-9→0, scaleY=.62→1 and opacity 0→1.
          .meetPRRiseIn(
            delay: 0,
            duration: MeetPRMotion.durationPill,
            offset: MeetPRMotion.pillInitialOffset,
            initialScaleY: MeetPRMotion.pillInitialScaleY
          )
      }
    }
  }
}

private struct MessageIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 21, y: 15))
    path.addQuadCurve(
      to: rect.svgPoint(x: 19, y: 17),
      control: rect.svgPoint(x: 21, y: 17)
    )
    path.addLine(to: rect.svgPoint(x: 7, y: 17))
    path.addLine(to: rect.svgPoint(x: 3, y: 21))
    path.addLine(to: rect.svgPoint(x: 3, y: 5))
    path.addQuadCurve(
      to: rect.svgPoint(x: 5, y: 3),
      control: rect.svgPoint(x: 3, y: 3)
    )
    path.addLine(to: rect.svgPoint(x: 19, y: 3))
    path.addQuadCurve(
      to: rect.svgPoint(x: 21, y: 5),
      control: rect.svgPoint(x: 21, y: 3)
    )
    path.closeSubpath()
    return path
  }
}

private struct ReadinessIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 12, y: 20))
    path.addCurve(
      to: rect.svgPoint(x: 4, y: 9),
      control1: rect.svgPoint(x: 9, y: 17),
      control2: rect.svgPoint(x: 4, y: 13)
    )
    path.addCurve(
      to: rect.svgPoint(x: 12, y: 5),
      control1: rect.svgPoint(x: 4, y: 4),
      control2: rect.svgPoint(x: 9, y: 3)
    )
    path.addCurve(
      to: rect.svgPoint(x: 20, y: 9),
      control1: rect.svgPoint(x: 15, y: 3),
      control2: rect.svgPoint(x: 20, y: 4)
    )
    path.addCurve(
      to: rect.svgPoint(x: 12, y: 20),
      control1: rect.svgPoint(x: 20, y: 13),
      control2: rect.svgPoint(x: 15, y: 17)
    )
    return path
  }
}

private struct CameraOutlineIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRoundedRect(
      in: rect.svgRect(x: 3, y: 6, width: 13, height: 12),
      cornerSize: CGSize(width: 2, height: 2)
    )
    path.move(to: rect.svgPoint(x: 16, y: 10))
    path.addLine(to: rect.svgPoint(x: 21, y: 8))
    path.addLine(to: rect.svgPoint(x: 21, y: 16))
    path.addLine(to: rect.svgPoint(x: 16, y: 14))
    return path
  }
}

private struct ClockOutlineIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addEllipse(in: rect.svgRect(x: 3, y: 3, width: 18, height: 18))
    path.move(to: rect.svgPoint(x: 12, y: 8))
    path.addLine(to: rect.svgPoint(x: 12, y: 12))
    path.addLine(to: rect.svgPoint(x: 14.5, y: 13.5))
    return path
  }
}

private struct ChevronUpIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 18, y: 15))
    path.addLine(to: rect.svgPoint(x: 12, y: 9))
    path.addLine(to: rect.svgPoint(x: 6, y: 15))
    return path
  }
}

extension CGRect {
  fileprivate func svgPoint(x: CGFloat, y: CGFloat) -> CGPoint {
    CGPoint(x: minX + x / 24 * width, y: minY + y / 24 * height)
  }

  fileprivate func svgRect(
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat
  ) -> CGRect {
    CGRect(
      x: minX + x / 24 * self.width,
      y: minY + y / 24 * self.height,
      width: width / 24 * self.width,
      height: height / 24 * self.height
    )
  }
}
