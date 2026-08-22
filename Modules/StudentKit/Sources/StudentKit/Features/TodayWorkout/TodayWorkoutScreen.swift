// swiftlint:disable file_length
import CoreModels
import DesignSystem
import SwiftUI

struct TodayWorkoutHeroFrameMeasurement: Equatable {
  let heroMode: TodayWorkoutPresentation.HeroMode
  let requestToken: Int
  let frame: CGRect

  var publishableFrame: CGRect? {
    guard frame.width > 0, frame.height > 0 else { return nil }
    return frame
  }
}

enum TodayWorkoutDayState: Equatable {
  case completed(canUndo: Bool)
  case current
  case upcoming(previousDay: StudentPlanDay?)

  var isEditable: Bool {
    if case .current = self { return true }
    return false
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct TodayWorkoutScreen<SequenceContent: View, CalendarContent: View>: View {
  enum Content {
    case loading
    case workout(TodayWorkoutPresentation)
    case noPlan
    case error(String)
  }

  let content: Content
  let weekCode: String
  let dayState: TodayWorkoutDayState
  let reviewCompleted: Bool
  let unreadCount: Int
  let showsNotifications: Bool
  let coachName: String
  let showsAskCoach: Bool
  let isPreparingAskCoach: Bool
  let namespace: Namespace.ID
  let isLaunchTargetHidden: Bool
  let heroFrameRequestToken: Int
  let launchHeroRevealToken: Int
  @Binding var collapsedExercises: [UUID: Bool]
  let sequenceContent: SequenceContent
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
  let onUndoCompletion: () -> Void
  let onShowReview: () -> Void

  var body: some View {
    trainingScrollView
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

      sequenceContent
      screenContent
      calendarContent
    }
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.top, MeetPRSpacing.point6)
    .padding(.bottom, MeetPRSpacing.point28)
  }

  @ViewBuilder
  private var screenContent: some View {
    // The design's training tab shows no state pill for the cursor day — the
    // whole screen already reads "current". The notice only earns its row on
    // completed (undo entry) and upcoming (preview) days.
    if case .current = dayState {
      EmptyView()
    } else {
      TodayWorkoutSequenceNotice(state: dayState, onUndo: onUndoCompletion)
    }

    switch content {
    case .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 220)
    case .workout(let presentation):
      TodayWorkoutHero(
        presentation: presentation,
        isEditable: dayState.isEditable,
        namespace: namespace,
        isLaunchTargetHidden: isLaunchTargetHidden,
        frameRequestToken: heroFrameRequestToken,
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

      }

      completionContent(presentation)
    case .noPlan:
      TodayWorkoutPlanUnavailableCard(
        coachName: coachName,
        onMessageCoach: onMessageCoach
      )
    case .error(let message):
      ContentUnavailableView(
        StudentStrings.localized(.todayWorkoutScreen001),
        systemImage: "exclamationmark.triangle",
        description: Text(message)
      )
      .frame(maxWidth: .infinity, minHeight: 220)
    }
  }

  @ViewBuilder
  private func completionContent(_ presentation: TodayWorkoutPresentation) -> some View {
    if case .completed = dayState {
      DayCompletionBanner(totalSets: presentation.exercises.flatMap(\.rows).count) {
        onShowReview()
      }
    } else if dayState.isEditable, presentation.allowsManualCompletion {
      // Ask-coach moved to the hero card's top-right corner once the action
      // row is gone (David 2026-08-08) — nothing sits above the hold button.
      if !presentation.progress.allDone {
        TodayWorkoutRemainingPill(text: presentation.progress.remainingText)
      }
      HoldToCompleteButton(action: onComplete)
    }
  }
}

// Hero-card corner variant: a compact「问教练」text chip instead of the
// action row's square icon (David 2026-08-08 真机走查).
private struct TodayWorkoutAskCoachCornerButton: View {
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
          Text(StudentStrings.askCoach)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
      }
      .padding(.horizontal, MeetPRSpacing.point13)
      .frame(minHeight: 36)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
      }
      .clipShape(.capsule)
      // 36pt visual capsule, 44pt hit target (MeetPRSpacing.minimumHitTarget).
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(isPreparing)
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

      Text(StudentStrings.localized(.todayWorkoutScreen002))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(StudentStrings.replacing(.todayWorkoutScreen003, values: ["\(coachName)"]))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textMuted)
        .multilineTextAlignment(.center)
        .lineSpacing(4)
        .frame(maxWidth: 260)
      Button(StudentStrings.localized(.todayWorkoutScreen004), action: onMessageCoach)
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
          TrainingHeaderButton(
            accessibilityLabel: StudentStrings.localized(.todayWorkoutScreen005), action: onRefresh
          ) {
            Image(systemName: "arrow.clockwise")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size17, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textSecondary)
          }

          TrainingHeaderButton(
            accessibilityLabel: StudentStrings.localized(.todayWorkoutScreen006),
            action: onReadiness
          ) {
            ReadinessIcon()
              .stroke(
                Color.MeetPR.textSecondary,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
              )
          }

          if showsNotifications {
            TrainingHeaderButton(
              accessibilityLabel: StudentStrings.localized(.todayWorkoutScreen007),
              action: onNotifications
            ) {
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

private struct TodayWorkoutHero: View {
  let presentation: TodayWorkoutPresentation
  let isEditable: Bool
  let namespace: Namespace.ID
  let isLaunchTargetHidden: Bool
  let frameRequestToken: Int
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
    .onGeometryChange(for: TodayWorkoutHeroFrameMeasurement.self) { proxy in
      TodayWorkoutHeroFrameMeasurement(
        heroMode: presentation.heroMode,
        requestToken: frameRequestToken,
        frame: proxy.frame(in: .global)
      )
    } action: { measurement in
      // Mode and request token participate in the measured value so the
      // current hero republishes even when its bounds match an older hero.
      if let frame = measurement.publishableFrame {
        onFrameChange(frame)
      }
    }
  }

  private var listHero: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
      TodayWorkoutActionSummary(presentation: presentation)
        .padding(.bottom, MeetPRSpacing.point14)

      if isEditable {
        GoldCTA(
          StudentStrings.localized(.todayWorkoutScreen008),
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
      // The design's recording state shows the active set card and the
      // per-exercise set table only — the「今日训练」summary card belongs to
      // the pre-start list state and never coexists with the active card
      // (David 2026-08-07 真机走查).
      VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
        HStack(alignment: .top, spacing: MeetPRSpacing.space2) {
          Text(exercise.name)
            .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
            .foregroundStyle(Color.MeetPR.textPrimary)

          Spacer(minLength: MeetPRSpacing.space2)

          // The one and only ask-coach entry: a「问教练」chip pinned to the
          // card's top-right corner for the whole recording session — the
          // action row's square icon and the old wide button are both gone
          // (David 2026-08-08 真机走查三连改).
          if showsAskCoach {
            TodayWorkoutAskCoachCornerButton(
              isPreparing: isPreparingAskCoach,
              action: onAskCoach
            )
          }
        }
        .padding(.bottom, MeetPRSpacing.point3)
        .launchHeroRise(index: 0, trigger: launchHeroRevealToken)

        Text(exercise.reference)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.bottom, MeetPRSpacing.point11)
          .launchHeroRise(index: 1, trigger: launchHeroRevealToken)

        HStack(spacing: MeetPRSpacing.space2) {
          Text(
            presentation.progress.allDone
              ? StudentStrings.localized(.todayWorkoutScreen009)
              : StudentStrings.localized(.todayWorkoutScreen010)
          )
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
              ? StudentStrings.localized(.todayWorkoutScreen011)
              : presentation.progress.positionText
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
          .accessibilityIdentifier("todayWorkout.activeSet.position")
        }
        .padding(.bottom, MeetPRSpacing.point10)
        .launchHeroRise(index: 2, trigger: launchHeroRevealToken)

        HStack(alignment: .bottom, spacing: MeetPRSpacing.point9) {
          Text(row.heroPrimaryText)
            .font(.MeetPR.display(size: MeetPRFontMetrics.size54))
            .foregroundStyle(Color.MeetPR.textPrimary)
          if row.heroShowsWeightUnit {
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
          Text(StudentStrings.localized(.todayWorkoutScreen012))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textMuted)
            .padding(.bottom, MeetPRSpacing.point9)
        }
        .launchHeroRise(index: 3, trigger: launchHeroRevealToken)

        if row.usesLegacyHero {
          // Pre-072 block, unchanged for legacy prescriptions (spec 072 §1.4).
          HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space2) {
            Text(StudentStrings.localized(.todayWorkoutScreen013))
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
        } else if let intensityText = row.heroSecondaryIntensityText {
          HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space2) {
            if let label = row.heroSecondaryLabelText {
              Text(label)
                .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
                .tracking(0.55)
                .foregroundStyle(Color.MeetPR.textFaint)
            }
            Text(intensityText)
              .font(.MeetPR.display(size: MeetPRFontMetrics.size20))
              .foregroundStyle(
                row.heroShowsWeightUnit
                  ? Color.MeetPR.textPrimary
                  : Color.MeetPR.textMuted
              )
          }
          .padding(.top, MeetPRSpacing.space2)
          .launchHeroRise(index: 4, trigger: launchHeroRevealToken)
        }

        if !exercise.note.isEmpty {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
            Text(StudentStrings.localized(.todayWorkoutScreen014))
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
              StudentStrings.localized(.todayWorkoutScreen015),
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
            .accessibilityLabel(StudentStrings.localized(.todayWorkoutScreen016))
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

// Pre-start list state only — the recording state never shows this card
// (David 2026-08-07: the active set card and the summary must not coexist).
private struct TodayWorkoutActionSummary: View {
  let presentation: TodayWorkoutPresentation

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point13) {
      TodayWorkoutActionSummaryHeader(presentation: presentation)

      VStack(spacing: MeetPRSpacing.space2) {
        ForEach(presentation.exercises) { exercise in
          TodayWorkoutActionSummaryRow(exercise: exercise)
        }
      }
    }
  }
}

private struct TodayWorkoutActionSummaryHeader: View {
  let presentation: TodayWorkoutPresentation

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text(StudentStrings.localized(.todayWorkoutScreen017))
          .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(
          StudentStrings.replacing(
            .todayWorkoutScreen018, values: ["\(presentation.exercises.count)"])
            + StudentStrings.replacing(
              .todayWorkoutScreen019, values: ["\(presentation.exercises.flatMap(\.rows).count)"])
        )
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
      }

      Spacer()
    }
  }
}

private struct TodayWorkoutActionSummaryRow: View {
  let exercise: TodayWorkoutPresentation.Exercise

  var body: some View {
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

      if let prescriptionSummary = exercise.prescriptionSummary {
        Text(prescriptionSummary)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
      } else if let first = exercise.rows.first?.record {
        // Pre-072 record-based summary, unchanged for legacy prescriptions.
        let weight = first.weight.map { numberText($0) + "kg" } ?? "—"
        Text(
          StudentStrings.replacing(
            .todayWorkoutScreen020,
            values: ["\(weight)", "\(first.reps)", "\(exercise.rows.count)"])
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
        meta: exercise.cardSubtitle,
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
  @State private var cancelFeedbackStep = 0
  @State private var successFeedbackStep = 0
  @State private var holdTask: Task<Void, Never>?
  @State private var gestureState = HoldToCompleteGestureState()

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
        Text(StudentStrings.localized(.todayWorkoutScreen021))
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
    .contentShape(.capsule)
    .highPriorityGesture(
      DragGesture(minimumDistance: 0)
        .onChanged(handleDragChanged)
        .onEnded { _ in apply(gestureState.dragEnded()) }
    )
    .sensoryFeedback(.impact(weight: .light), trigger: hapticStep)
    .sensoryFeedback(.warning, trigger: cancelFeedbackStep)
    .sensoryFeedback(.success, trigger: successFeedbackStep)
    .accessibilityElement()
    .accessibilityLabel(StudentStrings.localized(.todayWorkoutScreen022))
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { completeForAccessibility() }
    .onDisappear { holdTask?.cancel() }
  }

  private func handleDragChanged(_ value: DragGesture.Value) {
    let distance = hypot(value.translation.width, value.translation.height)
    apply(gestureState.dragChanged(isWithinBounds: distance <= 50))
  }

  private func beginHold() {
    isPressing = true
    holdTask?.cancel()
    if reduceMotion {
      progress = 1
    } else {
      withAnimation(.linear(duration: MeetPRMotion.durationHoldComplete)) {
        progress = 1
      }
    }
    holdTask = Task { @MainActor in
      for step in 1...7 {
        do {
          try await Task.sleep(
            for: .milliseconds(Int(MeetPRMotion.durationHoldComplete * 1_000 / 7))
          )
        } catch {
          return
        }
        guard gestureState.isHolding else { return }
        hapticStep = step
      }
      apply(gestureState.holdCompleted())
    }
  }

  private func cancelHold() {
    guard isPressing else { return }
    holdTask?.cancel()
    isPressing = false
    cancelFeedbackStep += 1
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

  private func complete() {
    guard isPressing else { return }
    holdTask?.cancel()
    isPressing = false
    progress = 1
    successFeedbackStep += 1
    action()
  }

  private func completeForAccessibility() {
    holdTask?.cancel()
    isPressing = false
    progress = 1
    successFeedbackStep += 1
    action()
  }

  private func resetAfterGesture() {
    holdTask?.cancel()
    isPressing = false
    progress = 0
  }

  private func apply(_ gestureAction: HoldToCompleteGestureState.Action?) {
    switch gestureAction {
    case .begin:
      beginHold()
    case .cancel:
      cancelHold()
    case .complete:
      complete()
    case .reset:
      resetAfterGesture()
    case nil:
      break
    }
  }
}

private struct TodayWorkoutSequenceNotice: View {
  let state: TodayWorkoutDayState
  let onUndo: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: MeetPRSpacing.space2) {
        Image(systemName: iconName)
        Text(title)
        Spacer()
        if case .completed(let canUndo) = state, canUndo {
          Button(StudentStrings.localized(.todayWorkoutScreen023), action: onUndo)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .bold))
            .buttonStyle(.plain)
        }
      }
      if case .upcoming(let previousDay) = state, let previousDay {
        Text(TrainingSequenceText.unlockMessage(after: previousDay))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
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

  private var title: String {
    switch state {
    case .completed: StudentStrings.localized(.todayWorkoutScreen024)
    case .current: StudentStrings.localized(.todayWorkoutScreen025)
    case .upcoming: StudentStrings.localized(.todayWorkoutScreen026)
    }
  }

  private var iconName: String {
    switch state {
    case .completed: "checkmark.circle"
    case .current: "record.circle"
    case .upcoming: "eye"
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
