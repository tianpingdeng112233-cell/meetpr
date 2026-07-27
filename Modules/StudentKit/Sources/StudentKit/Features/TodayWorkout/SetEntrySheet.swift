// swiftlint:disable file_length function_parameter_count type_body_length
import CoreModels
import DesignSystem
import Foundation
import SwiftUI

/// Full-screen set entry translated from the black-gold v3 SetEntry contract.
///
/// Persistence, video attachment, analytics, rest-timer and PR behavior remain
/// owned by their existing view models. This view only owns the transient values
/// shown while a set is being edited.
@available(iOS 17.0, macOS 14.0, *)
struct SetEntrySheet: View {
  let rowIndex: Int
  let draft: TodayWorkoutViewModel.SetRowDraft
  let setNumber: Int
  let viewModel: TodayWorkoutViewModel
  let studentID: UUID?
  let videoViewModel: VideoAttachmentViewModel?
  let scrollToVideo: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dismiss) private var dismiss

  @State private var weightText: String
  @State private var repsText: String
  @State private var rpeText: String
  @State private var activeNumberPad: MeetPRNumberPad.Field?
  @State private var focusedField: SetEntryNumberField?
  @State var collarOn: Bool

  var weightValue: Decimal { SetEntryValue.weight(from: weightText) }
  private var repsValue: Int { SetEntryValue.reps(from: repsText) }
  private var rpeValue: Decimal { SetEntryValue.rpe(from: rpeText) }

  init(
    rowIndex: Int,
    draft: TodayWorkoutViewModel.SetRowDraft,
    setNumber: Int,
    viewModel: TodayWorkoutViewModel,
    studentID: UUID? = nil,
    videoViewModel: VideoAttachmentViewModel? = nil,
    scrollToVideo: Bool = false
  ) {
    self.rowIndex = rowIndex
    self.draft = draft
    self.setNumber = setNumber
    self.viewModel = viewModel
    self.studentID = studentID
    self.videoViewModel = videoViewModel
    self.scrollToVideo = scrollToVideo
    _collarOn = State(initialValue: SetEntryPlateMath.defaultCollarOn)

    // Camera and picker presentations can recreate the cover. Re-seed from the
    // live, stable-id matched draft so flushed edits survive that churn.
    let seed = viewModel.currentDrafts?.first(where: { $0.id == draft.id }) ?? draft
    let suggestion = viewModel.weightSuggestion(forSetID: seed.id)
    let weight = seed.actualWeight ?? seed.prescribed.weightKg ?? suggestion?.weightKg ?? 20
    let reps = seed.actualReps ?? seed.prescribed.reps ?? seed.prescribed.repsMax ?? 0
    let rpe = seed.actualRPE ?? seed.prescribed.rpe ?? 8
    _weightText = State(initialValue: SetEntryValue.text(max(20, weight)))
    _repsText = State(initialValue: reps.formatted())
    _rpeText = State(initialValue: SetEntryValue.text(SetEntryValue.snapRPE(rpe)))
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      navigationBar

      ScrollView {
        VStack(spacing: MeetPRSpacing.zero) {
          if draft.allowsPlateLoadingGuidance {
            plateSection
          }

          VStack(spacing: MeetPRSpacing.space3) {
            numberStepper(
              label: "重量",
              annotation: "± 2.5",
              value: weightText,
              unit: "KG",
              onDecrement: {
                updateWeight(max(20, weightValue - Decimal(25) / 10))
              },
              onIncrement: {
                updateWeight(weightValue + Decimal(25) / 10)
              },
              onOpenPad: { openNumberPad(.weight) }
            )

            numberStepper(
              label: "次数",
              annotation: "± 1",
              value: repsText,
              unit: "次",
              onDecrement: { repsText = max(0, repsValue - 1).formatted() },
              onIncrement: { repsText = (repsValue + 1).formatted() },
              onOpenPad: { openNumberPad(.reps) }
            )

            rpeSection

            if let videoViewModel, let studentID {
              VideoAttachmentSection(
                studentID: studentID,
                videoViewModel: videoViewModel,
                initialSetLogID: liveDraft.loggedSetID,
                resolveSetLogID: {
                  syncDraftEdits()
                  return await viewModel.ensureLoggedSetID(rowIndex: rowIndex)
                },
                onWillPick: { syncDraftEdits() }
              )
              .id("setEntry.video")
            }
          }
          .padding(.top, draft.allowsPlateLoadingGuidance ? MeetPRSpacing.point6 : 0)
        }
        .padding(.horizontal, MeetPRSpacing.space4)
        .padding(.bottom, MeetPRSpacing.space4)
      }
      .defaultScrollAnchor(scrollToVideo ? .bottom : .top)
      .scrollIndicators(.hidden)

      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase.ignoresSafeArea())
    .modifier(SetEntryErrorAlert(viewModel: viewModel))
    .modifier(
      SetEntryAnalyticsModifier(
        weightText: weightText,
        repsText: repsText,
        rpeText: rpeText,
        focusedField: focusedField
      )
    )
    .overlay {
      if let activeNumberPad {
        numberPadOverlay(field: activeNumberPad)
          .transition(.opacity)
          .zIndex(1)
      }
    }
    .animation(reduceMotion ? nil : MeetPRMotion.sheet, value: activeNumberPad)
  }

  // MARK: - Navigation

  private var navigationBar: some View {
    ZStack {
      Text("\(draft.exerciseName) · 第 \(setNumber) 组")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineLimit(1)
        .padding(.horizontal, 88)

      HStack {
        Button {
          SetEntryAnalytics.trackCancel()
          dismiss()
        } label: {
          HStack(spacing: MeetPRSpacing.point3) {
            Image(systemName: "chevron.left")
              .font(.system(size: MeetPRFontMetrics.size18, weight: .semibold))
            Text("返回")
              .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
          }
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
        }
        .buttonStyle(PressScaleButtonStyle())

        Spacer()
      }
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.bottom, MeetPRSpacing.point3)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.MeetPR.borderDefault)
        .frame(height: 1)
    }
  }

  // MARK: - Plate guidance

  private var plateSection: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      PlateVisual(totalKg: totalWeight, hasCollar: collarOn)

      HStack(spacing: MeetPRSpacing.point10) {
        Text(breakdownLine)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineSpacing(MeetPRSpacing.point2)
          .frame(maxWidth: .infinity, alignment: .leading)

        collarToggle
      }
      .padding(.top, MeetPRSpacing.point6)
    }
  }

  private var collarToggle: some View {
    Button {
      collarOn.toggle()
    } label: {
      HStack(spacing: MeetPRSpacing.space2) {
        if collarOn {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: MeetPRFontMetrics.size17, weight: .semibold))
            .foregroundStyle(Color.MeetPR.gold500)
        } else {
          Circle()
            .stroke(Color.MeetPR.textMuted, lineWidth: 2)
            .frame(width: 17, height: 17)
        }

        Text("上赛扣")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .medium))
          .foregroundStyle(collarOn ? Color.MeetPR.textPrimary : Color.MeetPR.textMuted)
      }
      .padding(.horizontal, MeetPRSpacing.point14)
      .padding(.vertical, MeetPRSpacing.space2)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
      .overlay {
        Capsule()
          .stroke(
            collarOn
              ? Color.MeetPR.goldRGB.opacity(0.45)
              : Color.MeetPR.borderDefault,
            lineWidth: 1
          )
      }
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityIdentifier("setEntry.collarToggle")
  }

  // MARK: - Number steppers

  private func numberStepper(
    label: String,
    annotation: String,
    value: String,
    unit: String,
    onDecrement: @escaping @MainActor () -> Void,
    onIncrement: @escaping @MainActor () -> Void,
    onOpenPad: @escaping @MainActor () -> Void
  ) -> some View {
    VStack(spacing: MeetPRSpacing.space2) {
      HStack {
        Text(label)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .medium))
          .tracking(0.96)
          .foregroundStyle(Color.MeetPR.textMuted)
        Spacer()
        Text(annotation)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
          .foregroundStyle(Color.MeetPR.textMuted)
      }

      HStack(spacing: MeetPRSpacing.space3) {
        stepButton(systemImage: "minus", action: onDecrement)

        Button(action: onOpenPad) {
          HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point6) {
            Text(value)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size34, weight: .bold))
              .foregroundStyle(Color.MeetPR.textPrimary)
              .monospacedDigit()
              .contentTransition(.numericText())
            Text(unit)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
              .foregroundStyle(Color.MeetPR.textMuted)
          }
          .frame(maxWidth: .infinity)
          .frame(height: MeetPRFontMetrics.size54)
          .background(Color.MeetPR.surfaceCard)
          .clipShape(.rect(cornerRadius: MeetPRRadius.card))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(label) \(value) \(unit)")

        stepButton(systemImage: "plus", action: onIncrement)
      }
    }
  }

  private func stepButton(
    systemImage: String,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: MeetPRFontMetrics.size20, weight: .semibold))
        .foregroundStyle(Color.MeetPR.gold500)
        .frame(width: MeetPRSpacing.point48, height: MeetPRSpacing.point48)
        .background(Color.MeetPR.goldRGB.opacity(0.12))
        .clipShape(.circle)
        .overlay {
          Circle()
            .stroke(Color.MeetPR.goldRGB.opacity(0.3), lineWidth: 1)
        }
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  // MARK: - RPE

  private var rpeSection: some View {
    VStack(spacing: MeetPRSpacing.space2) {
      HStack {
        Text("RPE")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .medium))
          .tracking(0.96)
          .foregroundStyle(Color.MeetPR.textMuted)
        Spacer()
        Text("5–10 · 0.5")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
          .foregroundStyle(Color.MeetPR.textMuted)
      }

      SetEntryRPEScale(value: rpeBinding)
    }
  }

  private var rpeBinding: Binding<Double> {
    Binding(
      get: { NSDecimalNumber(decimal: rpeValue).doubleValue },
      set: { rpeText = SetEntryValue.rpeText($0) }
    )
  }

  // MARK: - NumberPad

  private func openNumberPad(_ field: MeetPRNumberPad.Field) {
    focusedField = field == .weight ? .weight : .reps
    activeNumberPad = field
  }

  private func closeNumberPad() {
    focusedField = nil
    activeNumberPad = nil
  }

  private func numberPadOverlay(field: MeetPRNumberPad.Field) -> some View {
    ZStack(alignment: .bottom) {
      Button(action: closeNumberPad) {
        Color.black.opacity(0.55)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.plain)
      .ignoresSafeArea()
      .accessibilityLabel("取消数字输入")

      MeetPRNumberPad(
        field: field,
        value: field == .weight ? totalWeight : Double(repsValue),
        onCommit: { value in
          switch field {
          case .weight:
            updateWeight(Decimal(value))
          case .reps:
            repsText = Int(value).formatted()
          }
          closeNumberPad()
        },
        onCancel: closeNumberPad
      )
      .transition(.move(edge: .bottom))
    }
  }

  // MARK: - Footer

  private var footer: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      SetEntryCompleteButton {
        save(failed: false)
      }

      Button {
        save(failed: true)
      } label: {
        HStack(spacing: MeetPRSpacing.point6) {
          Image(systemName: "xmark")
            .font(.system(size: MeetPRFontMetrics.size14, weight: .semibold))
          Text("未完成 / 失败")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        }
        .foregroundStyle(Color.MeetPR.textMuted)
        .frame(maxWidth: .infinity)
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      }
      .buttonStyle(PressScaleButtonStyle())
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.top, MeetPRSpacing.point10)
    .padding(.bottom, MeetPRSpacing.space5)
    .background(Color.MeetPR.bgBase)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderDefault)
        .frame(height: 1)
    }
  }

  private func updateWeight(_ weight: Decimal) {
    weightText = SetEntryValue.text(weight)
  }
}

enum SetEntryNumberField: Sendable {
  case weight
  case reps
  case rpe
}

// MARK: - Draft persistence

extension SetEntrySheet {
  fileprivate var liveDraft: TodayWorkoutViewModel.SetRowDraft {
    viewModel.currentDrafts?.first(where: { $0.id == draft.id }) ?? draft
  }

  fileprivate func syncDraftEdits() {
    viewModel.updateWeight(rowIndex: rowIndex, weight: weightValue)
    viewModel.updateReps(rowIndex: rowIndex, reps: repsValue)
    viewModel.updateRPE(rowIndex: rowIndex, rpe: rpeValue)
  }

  fileprivate func save(failed: Bool) {
    closeNumberPad()
    syncDraftEdits()
    Task {
      if await viewModel.commitSet(rowIndex: rowIndex, failed: failed) {
        SetEntryAnalytics.trackCommit(
          draft: liveDraft,
          videoViewModel: videoViewModel,
          failed: failed
        )
        dismiss()
      }
    }
  }
}

private struct SetEntryErrorAlert: ViewModifier {
  let viewModel: TodayWorkoutViewModel

  private var isPresented: Binding<Bool> {
    Binding(
      get: { viewModel.actionErrorMessage != nil },
      set: { if !$0 { viewModel.clearActionError() } }
    )
  }

  func body(content: Content) -> some View {
    content.alert("保存失败", isPresented: isPresented) {
      Button("知道了", role: .cancel) {
        viewModel.clearActionError()
      }
    } message: {
      Text(viewModel.actionErrorMessage ?? "")
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SetEntryCompleteButton: View {
  @Environment(\.colorScheme) private var colorScheme
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.space2) {
        Image(systemName: "checkmark")
          .font(.system(size: MeetPRFontMetrics.size20, weight: .bold))
        Text("完成本组")
          .font(.MeetPR.display(size: MeetPRFontMetrics.size16))
      }
      .foregroundStyle(Color.MeetPR.ctaText)
      .frame(maxWidth: .infinity)
      .frame(height: MeetPRSpacing.point52)
      .background(Color.MeetPR.ctaBackground)
      .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
      .overlay(alignment: .top) {
        if colorScheme == .dark {
          Capsule()
            .stroke(Color.MeetPR.ctaTopHighlight.opacity(0.55), lineWidth: 1.5)
            .mask(alignment: .top) {
              Rectangle().frame(height: MeetPRSpacing.point2)
            }
        }
      }
      .overlay(alignment: .bottom) {
        if colorScheme == .dark {
          Capsule()
            .stroke(Color.MeetPR.ctaBottomShade.opacity(0.25), lineWidth: 2)
            .mask(alignment: .bottom) {
              Rectangle().frame(height: MeetPRSpacing.point3)
            }
        }
      }
      .shadow(
        color: outerShadow?.color ?? .clear,
        radius: outerShadow?.swiftUIRadius ?? 0,
        x: outerShadow?.offsetX ?? 0,
        y: outerShadow?.offsetY ?? 0
      )
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var outerShadow: MeetPRShadowToken? {
    MeetPRVisualEffects.ctaMold(for: colorScheme)
      .last(where: { !$0.isInset && $0.blur > 0 })
  }
}

// swiftlint:enable file_length function_parameter_count type_body_length
