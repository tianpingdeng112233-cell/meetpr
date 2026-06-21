import CoreModels
import DesignSystem
import Foundation
import SwiftUI

/// Set-entry sheet with the loaded-barbell plate calculator (design
/// `SetEntryPlate`): a live `PlateLoadout` barbell for the dialed weight, the
/// big-plates-first breakdown (the 2.5 kg locking collar counts toward the
/// load), big +/- steppers for weight / reps / RPE, optional video attach, and
/// the complete / fail actions. Commit + video logic unchanged.
@available(iOS 17.0, macOS 14.0, *)
struct SetEntrySheet: View {
  let rowIndex: Int
  let draft: TodayWorkoutViewModel.SetRowDraft
  let viewModel: TodayWorkoutViewModel
  /// Video attach context (spec 027); nil hides the video block entirely.
  let studentID: UUID?
  let videoViewModel: VideoAttachmentViewModel?
  @Environment(\.dismiss) private var dismiss

  @State private var weight: Decimal
  @State private var reps: Int
  @State private var rpe: Decimal

  private let bar = 20.0
  private let collar = 2.5  // per-side locking collar — counts toward the load

  init(
    rowIndex: Int,
    draft: TodayWorkoutViewModel.SetRowDraft,
    viewModel: TodayWorkoutViewModel,
    studentID: UUID? = nil,
    videoViewModel: VideoAttachmentViewModel? = nil
  ) {
    self.rowIndex = rowIndex
    self.draft = draft
    self.viewModel = viewModel
    self.studentID = studentID
    self.videoViewModel = videoViewModel
    _weight = State(initialValue: draft.actualWeight ?? draft.prescribed.weightKg ?? 0)
    _reps = State(
      initialValue: draft.actualReps ?? draft.prescribed.reps ?? draft.prescribed.repsMax ?? 0)
    _rpe = State(initialValue: draft.actualRPE ?? draft.prescribed.rpe ?? 8)
  }

  var body: some View {
    VStack(spacing: 0) {
      navBar
      ScrollView {
        VStack(spacing: 0) {
          PlateLoadout(plates: plates).padding(.top, 8)
          Text(breakdownLine)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

          VStack(spacing: 18) {
            plateStepper(
              "重量", value: StudentFormatting.decimal(weight), unit: "KG", sub: "± 2.5",
              onDec: { weight = max(0, weight - 2.5) }, onInc: { weight += 2.5 })
            plateStepper(
              "次数", value: "\(reps)", unit: "次", sub: "± 1",
              onDec: { reps = max(0, reps - 1) }, onInc: { reps += 1 })
            plateStepper(
              "RPE", value: StudentFormatting.decimal(rpe), unit: nil, sub: "± 0.5 · 5–10",
              onDec: { rpe = max(5, rpe - 0.5) }, onInc: { rpe = min(10, rpe + 0.5) })

            if let videoViewModel, let studentID {
              VideoAttachmentSection(
                studentID: studentID,
                videoViewModel: videoViewModel,
                initialSetLogID: draft.loggedSetID,
                resolveSetLogID: { await viewModel.ensureLoggedSetID(rowIndex: rowIndex) }
              )
            }
          }
          .padding(.top, 28)
        }
        .padding(16)
      }
      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
    .presentationDetents([.large])
  }

  // MARK: - Plate loadout

  private var perSide: Double {
    (NSDecimalNumber(decimal: weight).doubleValue - bar) / 2 - collar
  }

  private var plates: [Double] {
    perSide > 1e-6 ? PlateLoadout.load(perSide: perSide) : []
  }

  private var breakdownLine: String {
    let total = NSDecimalNumber(decimal: weight).doubleValue
    guard total >= bar + collar * 2 else { return "空杠 20kg" }
    let base = PlateLoadout.breakdownText(plates)
    return base.isEmpty ? "仅 2.5kg 卡扣" : base + " + 2.5kg 卡扣"
  }

  // MARK: - Chrome

  private var navBar: some View {
    ZStack {
      Text("\(draft.exerciseName) · 第 \(draft.prescribed.setIndex + 1) 组")
        .font(Font.MeetPR.body.weight(.semibold))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      HStack {
        Button {
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
      actionButton("完成本组", icon: "checkmark", background: Color.MeetPR.green, foreground: .white) {
        save(failed: false)
      }
      actionButton(
        "未完成 / 失败", icon: "xmark", background: Color.MeetPR.amber,
        foreground: Color.MeetPR.fgPrimary
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
    }
    .buttonStyle(.plain)
  }

  // MARK: - Steppers

  private func plateStepper(
    _ label: String, value: String, unit: String?, sub: String,
    onDec: @escaping () -> Void, onInc: @escaping () -> Void
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
        HStack(alignment: .lastTextBaseline, spacing: 6) {
          Text(value)
            .font(.system(size: 40, weight: .heavy, design: .monospaced))
            .foregroundStyle(Color.MeetPR.fgPrimary)
          if let unit {
            Text(unit).font(.system(size: 14, weight: .bold)).foregroundStyle(
              Color.MeetPR.fgTertiary)
          }
        }
        .frame(maxWidth: .infinity)
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

  private func save(failed: Bool) {
    viewModel.updateWeight(rowIndex: rowIndex, weight: weight)
    viewModel.updateReps(rowIndex: rowIndex, reps: reps)
    viewModel.updateRPE(rowIndex: rowIndex, rpe: rpe)
    Task { await viewModel.commitSet(rowIndex: rowIndex, failed: failed) }
    dismiss()
  }
}
