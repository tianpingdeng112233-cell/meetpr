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
    VStack(spacing: 0) {
      navBar
      ScrollView {
        VStack(spacing: 0) {
          if draft.allowsPlateLoadingGuidance {
            PlateLoadout(plates: plates, showCollar: collarOn).padding(.top, 8)
            Text(breakdownLine)
              .font(.system(size: 14, weight: .semibold, design: .monospaced))
              .foregroundStyle(Color.MeetPR.fgPrimary)
              .frame(maxWidth: .infinity)
              .padding(.top, 4)
            collarToggle.padding(.top, 10)
          }

          VStack(spacing: 18) {
            VStack(spacing: 6) {
              plateStepper(
                "重量", unit: "KG", sub: "± 2.5",
                onDec: { updateWeightText(max(0, weightValue - 2.5)) },
                onInc: { updateWeightText(weightValue + 2.5) },
                focus: { focusedField = .weight },
                field: {
                  TextField("", text: weightTextBinding)
                    .decimalKeyboard()
                    .focused($focusedField, equals: .weight)
                    .accessibilityLabel("重量")
                    .maxInputLength($weightText, 6)
                    .modifier(EntryFieldStyle())
                }
              )
              if let weightSuggestion {
                Text(suggestionLabel(weightSuggestion))
                  .font(Font.MeetPR.footnote)
                  .foregroundStyle(Color.MeetPR.fgTertiary)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
            plateStepper(
              "次数", unit: "次", sub: "± 1",
              onDec: { repsText = "\(max(0, repsValue - 1))" },
              onInc: { repsText = "\(repsValue + 1)" },
              focus: { focusedField = .reps },
              field: {
                TextField("", text: $repsText)
                  .numberPadKeyboard()
                  .focused($focusedField, equals: .reps)
                  .accessibilityLabel("次数")
                  .maxInputLength($repsText, 4)
                  .modifier(EntryFieldStyle())
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
        .padding(16)
      }
      .defaultScrollAnchor(scrollToVideo ? .bottom : .top)
      .scrollDismissesKeyboard(.interactively)
      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
    .presentationDetents([.large])
    .modifier(SetEntryErrorAlert(viewModel: viewModel))
    .modifier(
      SetEntryAnalyticsModifier(
        weightText: weightText,
        repsText: repsText,
        rpeText: rpeText,
        focusedField: focusedField)
    )
    #if os(iOS)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("完成") { focusedField = nil }
          .foregroundStyle(Color.MeetPR.brandRed)
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
        HStack(spacing: 8) {
          Image(systemName: collarOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18))
            .foregroundStyle(collarOn ? Color.MeetPR.brandRed : Color.MeetPR.fgTertiary)
          Text("上赛扣")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(collarOn ? Color.MeetPR.fgPrimary : Color.MeetPR.fgTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.MeetPR.surface1)
        .clipShape(Capsule())
        .overlay {
          Capsule().stroke(
            collarOn ? Color.MeetPR.brandRed.opacity(0.4) : Color.MeetPR.border, lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("setEntry.collarToggle")
    }
  }

  // MARK: - RPE tick-scale

  /// RPE band: the same mono label row as the steppers, then the drag-to-pick
  /// tick scale (SetEntryRPEScale) in place of the old +/- box.
  private var rpeSection: some View {
    VStack(spacing: 8) {
      HStack {
        Text("RPE")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.fgTertiary)
        Spacer()
        Text("5–10 · 0.5")
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(Color.MeetPR.fgTertiary)
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
        .foregroundStyle(Color.MeetPR.fgPrimary)
      HStack {
        Button {
          SetEntryAnalytics.trackCancel()
          dismiss()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left")
            Text("返回")
          }
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        }
        .buttonStyle(.plain)
        Spacer()
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .overlay(alignment: .bottom) { Rectangle().fill(Color.MeetPR.border).frame(height: 1) }
  }

  private var footer: some View {
    VStack(spacing: 10) {
      // Primary = inverted fill (white-on-dark in the dark sheet), secondary =
      // ghost with a hairline border, per the record-v2 mockup.
      actionButton(
        "完成本组", icon: "checkmark",
        background: Color.MeetPR.fgPrimary, foreground: Color.MeetPR.bg
      ) {
        save(failed: false)
      }
      actionButton(
        "未完成 / 失败", icon: "xmark", background: Color.MeetPR.surface1,
        foreground: Color.MeetPR.fgSecondary, border: Color.MeetPR.border
      ) {
        save(failed: true)
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 24)
    .background(Color.MeetPR.bg)
    .overlay(alignment: .top) { Rectangle().fill(Color.MeetPR.border).frame(height: 1) }
  }

  private func actionButton(
    _ title: String, icon: String, background: Color, foreground: Color,
    border: Color? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
        Text(title)
      }
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(foreground)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(background)
      .clipShape(.rect(cornerRadius: 12))
      .overlay {
        if let border {
          RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1)
        }
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Steppers

  private func plateStepper<Field: View>(
    _ label: String, unit: String?, sub: String,
    onDec: @escaping () -> Void, onInc: @escaping () -> Void,
    focus: @escaping () -> Void,
    @ViewBuilder field: () -> Field
  ) -> some View {
    VStack(spacing: 8) {
      HStack {
        Text(label)
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.fgTertiary)
        Spacer()
        Text(sub).font(.system(size: 10, design: .monospaced)).foregroundStyle(
          Color.MeetPR.fgTertiary)
      }
      HStack(spacing: 12) {
        stepButton("minus", action: onDec)
        // Filled slot marks the value as a tap-to-type input (students missed the
        // bare-label number); tapping anywhere in the slot focuses the field.
        HStack(alignment: .lastTextBaseline, spacing: 6) {
          field()
          if let unit {
            Text(unit).font(.system(size: 14, weight: .bold)).foregroundStyle(
              Color.MeetPR.fgTertiary)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.MeetPR.surface2))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: focus)
        stepButton("plus", action: onInc)
      }
    }
  }

  private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 20))
        .foregroundStyle(Color.MeetPR.brandRed)
        .frame(width: 52, height: 52)
        .background(Color.MeetPR.brandRedSoft)
        .clipShape(Circle())
        .overlay { Circle().stroke(Color.MeetPR.brandRed.opacity(0.3), lineWidth: 1) }
    }
    .buttonStyle(.plain)
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
      .font(.system(size: 40, weight: .heavy, design: .monospaced))
      .foregroundStyle(Color.MeetPR.fgPrimary)
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
