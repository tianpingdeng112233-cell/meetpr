// swiftlint:disable function_parameter_count file_length
import CoreModels
import DesignSystem
import Foundation
import SwiftUI

/// Set-entry sheet with the loaded-barbell plate calculator (design
/// `SetEntryPlate`): main lifts show a live `PlateLoadout` barbell for the
/// dialed weight, the big-plates-first breakdown (the 2.5 kg competition collar
/// 赛扣 counts toward the load only when 上赛扣 is toggled on), big +/- steppers
/// for weight / reps / RPE, optional video attach, and the complete / fail
/// actions. Accessory exercises omit the plate-loading guidance. Commit + video
/// logic unchanged.
@available(iOS 17.0, macOS 14.0, *)
// swiftlint:disable:next type_body_length
struct SetEntrySheet: View {
  let rowIndex: Int
  let draft: TodayWorkoutViewModel.SetRowDraft
  let setNumber: Int
  let viewModel: TodayWorkoutViewModel
  /// Video attach context (spec 027); nil hides the video block entirely.
  let studentID: UUID?
  let videoViewModel: VideoAttachmentViewModel?
  /// When true the sheet opens scrolled to the bottom (video attach + actions),
  /// e.g. when launched from the camera affordance.
  let scrollToVideo: Bool
  @Environment(\.dismiss) private var dismiss

  // Bound to editable text (not TextField(value:format:)) so the value read in
  // save() is always the current text — the numeric mirror is derived, never
  // waiting on a focus-loss parse. See SetEntryValue.
  @State private var weightText: String
  @State private var repsText: String
  @State private var rpeText: String
  @State private var weightSuggestion: SetWeightSuggestion?
  /// Which value the bottom-sheet keypad is editing; nil = closed (§3 NumberPad).
  @State private var numberPadField: MeetPRNumberPad.Field?
  @FocusState private var focusedField: SetEntryNumberField?
  /// Whether the 2.5kg competition collar (赛扣) is loaded. When on it counts
  /// toward the dialed weight, so the plates drop 2.5kg per side; the barbell
  /// graphic and breakdown follow. Persisted under a per-student key (review
  /// finding 2026-07-17: a global key leaked one account's choice into the
  /// next login on a shared device) so the choice sticks across sets and
  /// launches; defaults off (bare plates). Internal so the plate-math
  /// extension (SetEntryPlateLoadout.swift) can read it.
  @AppStorage var collarOn: Bool

  var weightValue: Decimal { SetEntryValue.weight(from: weightText) }

  /// The analytics-visible field while the number pad edits weight or reps.
  private var numberPadEditingField: SetEntryNumberField? {
    switch numberPadField {
    case .weight: .weight
    case .reps: .reps
    case nil: nil
    }
  }
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
    _collarOn = AppStorage(
      wrappedValue: false, SetEntryPlateMath.collarDefaultsKey(for: studentID))
    // Seed from the live draft, not the open-time snapshot: if presentation
    // churn (e.g. the camera cover) recreates this sheet, flushed edits must
    // reappear instead of the stale prescribed values (beta 2026-07-11).
    // Matched by stable id, never by index — after a day switch the same
    // index can belong to a different set entirely.
    let seed = viewModel.currentDrafts?.first(where: { $0.id == draft.id }) ?? draft
    let suggestion = viewModel.weightSuggestion(forSetID: seed.id)
    let weight = seed.actualWeight ?? seed.prescribed.weightKg ?? suggestion?.weightKg ?? 0
    let reps = seed.actualReps ?? seed.prescribed.reps ?? seed.prescribed.repsMax ?? 0
    let rpe = seed.actualRPE ?? seed.prescribed.rpe ?? 8
    _weightText = State(initialValue: SetEntryValue.text(weight))
    _repsText = State(initialValue: "\(reps)")
    // Snap the seed so a non-0.5 prescribed/legacy RPE lands on a tick.
    _rpeText = State(initialValue: SetEntryValue.text(SetEntryValue.snapRPE(rpe)))
    _weightSuggestion = State(initialValue: suggestion)
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      navBar
      ScrollView {
        VStack(spacing: MeetPRSpacing.zero) {
          if draft.allowsPlateLoadingGuidance {
            PlateLoadout(plates: plates, showCollar: collarOn)
              .padding(.top, MeetPRSpacing.space2)
            Text(breakdownLine)
              .font(
                .MeetPR.system(
                  size: MeetPRFontMetrics.size14, weight: .semibold, design: .monospaced)
              )
              .foregroundStyle(Color.MeetPR.textPrimary)
              .frame(maxWidth: .infinity)
              .padding(.top, MeetPRSpacing.space1)
            collarToggle
              .padding(.top, MeetPRSpacing.point10)
          }

          VStack(spacing: MeetPRSpacing.point18) {
            VStack(spacing: MeetPRSpacing.point6) {
              plateStepper(
                "重量", unit: "KG", sub: "± 2.5",
                onDec: { updateWeightText(max(0, weightValue - 2.5)) },
                onInc: { updateWeightText(weightValue + 2.5) },
                focus: { numberPadField = .weight },
                field: {
                  Text(weightText.isEmpty ? "0" : weightText)
                    .modifier(EntryFieldStyle())
                    .accessibilityLabel("重量 \(weightText)")
                    .accessibilityHint("打开数字键盘修改")
                }
              )
              if let weightSuggestion {
                Text(suggestionLabel(weightSuggestion))
                  .font(Font.MeetPR.footnote)
                  .foregroundStyle(Color.MeetPR.textTertiary)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
            plateStepper(
              "次数", unit: "次", sub: "± 1",
              onDec: { repsText = "\(max(0, repsValue - 1))" },
              onInc: { repsText = "\(repsValue + 1)" },
              focus: { numberPadField = .reps },
              field: {
                Text(repsText.isEmpty ? "0" : repsText)
                  .modifier(EntryFieldStyle())
                  .accessibilityLabel("次数 \(repsText)")
                  .accessibilityHint("打开数字键盘修改")
              }
            )
            rpeSection

            if let videoViewModel, let studentID {
              VideoAttachmentSection(
                studentID: studentID,
                videoViewModel: videoViewModel,
                initialSetLogID: liveDraft.loggedSetID,
                resolveSetLogID: {
                  // Attaching to an unlogged set persists it to mint a set-log
                  // id — flush the typed numbers first, or the stale draft
                  // wipes them and logs prescribed values (beta 2026-07-11).
                  syncDraftEdits()
                  return await viewModel.ensureLoggedSetID(rowIndex: rowIndex)
                },
                // Flush on 拍摄/相册 tap too: the camera cover's dismissal can
                // recreate this sheet, and the reseed above only helps if the
                // values are already in the draft by then.
                onWillPick: { syncDraftEdits() }
              )
            }
          }
          .padding(.top, draft.allowsPlateLoadingGuidance ? 28 : 0)
        }
        .padding(MeetPRSpacing.space4)
      }
      .defaultScrollAnchor(scrollToVideo ? .bottom : .top)
      .scrollDismissesKeyboard(.interactively)
      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .presentationDetents([.large])
    .sheet(
      isPresented: Binding(
        get: { numberPadField != nil },
        set: { if !$0 { numberPadField = nil } }
      )
    ) {
      if let field = numberPadField {
        MeetPRNumberPad(
          field: field,
          value: field == .weight
            ? (weightValue as NSDecimalNumber).doubleValue : Double(repsValue),
          onCommit: { snapped in
            switch field {
            case .weight: updateWeightText(Decimal(snapped))
            case .reps: repsText = "\(Int(snapped))"
            }
            numberPadField = nil
          },
          onCancel: { numberPadField = nil }
        )
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
      }
    }
    .modifier(SetEntryErrorAlert(viewModel: viewModel))
    .modifier(
      SetEntryAnalyticsModifier(
        weightText: weightText,
        repsText: repsText,
        rpeText: rpeText,
        // Weight/reps re-edits now happen in the number-pad sheet, so the
        // friction trackers follow its lifecycle; RPE keeps the focus path.
        focusedField: numberPadEditingField ?? focusedField)
    )
    #if os(iOS)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("完成") { focusedField = nil }
          .foregroundStyle(Color.MeetPR.gold500)
        }
      }
    #endif
  }

  // MARK: - Collar toggle (赛扣)

  /// 贴右的小圆勾选：是否上赛扣。图示 + 明细随之联动，选择记忆到下次。
  private var collarToggle: some View {
    HStack {
      Spacer()
      Button {
        collarOn.toggle()
      } label: {
        HStack(spacing: MeetPRSpacing.space2) {
          Image(systemName: collarOn ? "checkmark.circle.fill" : "circle")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size18))
            .foregroundStyle(collarOn ? Color.MeetPR.gold500 : Color.MeetPR.textTertiary)
          Text("上赛扣")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size14, weight: .medium))
            .foregroundStyle(collarOn ? Color.MeetPR.textPrimary : Color.MeetPR.textTertiary)
        }
        .padding(.horizontal, MeetPRSpacing.point14)
        .padding(.vertical, MeetPRSpacing.space2)
        .background(Color.MeetPR.surfaceCard)
        .clipShape(Capsule())
        .overlay {
          Capsule().stroke(
            collarOn ? Color.MeetPR.gold500.opacity(0.4) : Color.MeetPR.borderDefault, lineWidth: 1)
        }
      }
      .buttonStyle(PressScaleButtonStyle())
      .accessibilityIdentifier("setEntry.collarToggle")
    }
  }

  // MARK: - RPE tick-scale

  /// RPE band: the same mono label row as the steppers, then the drag-to-pick
  /// tick scale (SetEntryRPEScale) in place of the old +/- box.
  private var rpeSection: some View {
    VStack(spacing: MeetPRSpacing.space2) {
      HStack {
        Text("RPE")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.textTertiary)
        Spacer()
        Text("5–10 · 0.5")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size10, design: .monospaced))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      SetEntryRPEScale(value: rpeBinding)
    }
  }

  /// Bridges the scale's `Double` to the shared `rpeText` state so save() and
  /// analytics keep reading one source of truth. `rpeValue` is already snapped to
  /// 0.5, so the scale always lands on a tick; the setter snaps with exact
  /// integer math rather than a `String(format:)` round-trip.
  private var rpeBinding: Binding<Double> {
    Binding(
      get: { NSDecimalNumber(decimal: rpeValue).doubleValue },
      set: { rpeText = SetEntryValue.rpeText($0) }
    )
  }

  private var weightTextBinding: Binding<String> {
    Binding(
      get: { weightText },
      set: {
        weightText = $0
        weightSuggestion = nil
      }
    )
  }

  private func updateWeightText(_ weight: Decimal) {
    weightText = SetEntryValue.text(weight)
    weightSuggestion = nil
  }

  private func suggestionLabel(_ suggestion: SetWeightSuggestion) -> String {
    switch suggestion.basis {
    case .previousSet:
      "建议 · 同上组"
    case .e1RM(let value):
      "建议 · 基于 e1RM \(StudentFormatting.kilograms(value))"
    case .lastLogged:
      "建议 · 上次重量"
    }
  }

  // MARK: - Chrome

  private var navBar: some View {
    ZStack {
      Text("\(draft.exerciseName) · 第 \(setNumber) 组")
        .font(Font.MeetPR.body.weight(.semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      HStack {
        Button {
          SetEntryAnalytics.trackCancel()
          dismiss()
        } label: {
          HStack(spacing: MeetPRSpacing.space1) {
            Image(systemName: "chevron.left")
            Text("返回")
          }
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.textPrimary)
        }
        .buttonStyle(PressScaleButtonStyle())
        Spacer()
      }
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point10)
    .overlay(alignment: .bottom) { Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1) }
  }

  private var footer: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      // Primary = inverted fill (white-on-dark in the dark sheet), secondary =
      // ghost with a hairline border, per the record-v2 mockup.
      actionButton(
        "完成本组", icon: "checkmark",
        background: Color.MeetPR.ctaBackground, foreground: Color.MeetPR.ctaText
      ) {
        save(failed: false)
      }
      actionButton(
        "未完成 / 失败", icon: "xmark", background: Color.MeetPR.surfaceCard,
        foreground: Color.MeetPR.textSecondary, border: Color.MeetPR.borderDefault
      ) {
        save(failed: true)
      }
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.top, MeetPRSpacing.space3)
    .padding(.bottom, MeetPRSpacing.space6)
    .background(Color.MeetPR.bgBase)
    .overlay(alignment: .top) { Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1) }
  }

  private func actionButton(
    _ title: String, icon: String, background: Color, foreground: Color,
    border: Color? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.space2) {
        Image(systemName: icon)
        Text(title)
      }
      .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .semibold))
      .foregroundStyle(foreground)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(background)
      .clipShape(.rect(cornerRadius: title == "完成本组" ? MeetPRRadius.pill : 12))
      .overlay {
        if let border {
          RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(border, lineWidth: 1)
        }
      }
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  // MARK: - Steppers

  private func plateStepper<Field: View>(
    _ label: String, unit: String?, sub: String,
    onDec: @escaping () -> Void, onInc: @escaping () -> Void,
    focus: @escaping () -> Void,
    @ViewBuilder field: () -> Field
  ) -> some View {
    VStack(spacing: MeetPRSpacing.space2) {
      HStack {
        Text(label)
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.textTertiary)
        Spacer()
        Text(sub).font(.MeetPR.system(size: MeetPRFontMetrics.size10, design: .monospaced))
          .foregroundStyle(
            Color.MeetPR.textTertiary)
      }
      HStack(spacing: MeetPRSpacing.space3) {
        stepButton("minus", action: onDec)
        // The entire filled slot is one 54pt button (students missed the bare
        // number): tapping value, unit, or whitespace opens the number pad.
        Button(action: focus) {
          HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point6) {
            field()
            if let unit {
              Text(unit).font(.MeetPR.system(size: MeetPRFontMetrics.size14, weight: .bold))
                .foregroundStyle(
                  Color.MeetPR.textTertiary)
            }
          }
          .frame(maxWidth: .infinity)
          .frame(height: 54)
          .background(
            RoundedRectangle(cornerRadius: MeetPRRadius.card).fill(Color.MeetPR.surfaceCard)
          )
          .contentShape(RoundedRectangle(cornerRadius: MeetPRRadius.card))
        }
        .buttonStyle(PressScaleButtonStyle())

        stepButton("plus", action: onInc)
      }
    }
  }

  private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size20))
        .foregroundStyle(Color.MeetPR.gold500)
        .frame(width: 48, height: 48)
        .background(Color.MeetPR.goldSoft)
        .clipShape(Circle())
        .overlay { Circle().stroke(Color.MeetPR.gold500.opacity(0.3), lineWidth: 1) }
    }
    .buttonStyle(PressScaleButtonStyle())
  }

}

enum SetEntryNumberField: Sendable {
  case weight
  case reps
  case rpe
}

// MARK: - Draft persistence
extension SetEntrySheet {
  /// The current view-model draft for this set, matched by stable id; falls
  /// back to the open-time snapshot when the set is no longer on screen.
  fileprivate var liveDraft: TodayWorkoutViewModel.SetRowDraft {
    viewModel.currentDrafts?.first(where: { $0.id == draft.id }) ?? draft
  }

  /// Push the sheet's current field values into the view model draft; both
  /// save() and the video-attach path need the draft current before persist.
  fileprivate func syncDraftEdits() {
    viewModel.updateWeight(rowIndex: rowIndex, weight: weightValue)
    viewModel.updateReps(rowIndex: rowIndex, reps: repsValue)
    viewModel.updateRPE(rowIndex: rowIndex, rpe: rpeValue)
  }

  fileprivate func save(failed: Bool) {
    // Parse + clamp the current field text here (not while typing), so a
    // multi-digit value like "10" RPE is never truncated mid-keystroke and the
    // saved value is always what the field currently shows.
    focusedField = nil
    syncDraftEdits()
    Task {
      if await viewModel.commitSet(rowIndex: rowIndex, failed: failed) {
        SetEntryAnalytics.trackCommit(
          draft: liveDraft, videoViewModel: videoViewModel, failed: failed)
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
      Button("知道了", role: .cancel) { viewModel.clearActionError() }
    } message: {
      Text(viewModel.actionErrorMessage ?? "")
    }
  }
}

/// Typography for the editable number inside the slot; the tap-to-type affordance
/// comes from the filled slot in plateStepper, not from the text itself.
private struct EntryFieldStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .font(.MeetPR.mono(size: 34, weight: .bold))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: true, vertical: false)
  }
}

/// `keyboardType` is iOS-only; the StudentKit package also builds for macOS
/// (test target), so wrap it platform-guarded no-ops.
@available(iOS 17.0, macOS 14.0, *)
extension View {
  @ViewBuilder
  fileprivate func decimalKeyboard() -> some View {
    #if os(iOS)
      keyboardType(.decimalPad)
    #else
      self
    #endif
  }

  @ViewBuilder
  fileprivate func numberPadKeyboard() -> some View {
    #if os(iOS)
      keyboardType(.numberPad)
    #else
      self
    #endif
  }

  /// Cap the entered text so a runaway value (paste, hardware keyboard) can't
  /// widen the `fixedSize` field past its slot and shove the buttons off-screen.
  fileprivate func maxInputLength(_ text: Binding<String>, _ limit: Int) -> some View {
    onChange(of: text.wrappedValue) { _, newValue in
      if newValue.count > limit { text.wrappedValue = String(newValue.prefix(limit)) }
    }
  }
}
// swiftlint:enable function_parameter_count
