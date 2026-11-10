import DesignSystem
import SwiftUI

/// Spec 108's body-weight variant of the spec 105 in-app keypad.
/// Text editing shares NumberPadTextInput; dismissing never commits a weight.
struct BodyWeightNumberPad: View {
  let initialText: String
  var lastRecord: BodyWeightRecord?
  var isSaving = false
  var saveFailed = false
  let onChange: (String) -> Void
  let onSave: (String) -> Void
  let onCancel: () -> Void
  @State private var input: NumberPadTextInput
  @State private var feedback = 0

  init(
    initialText: String, lastRecord: BodyWeightRecord? = nil,
    isSaving: Bool = false, saveFailed: Bool = false,
    onChange: @escaping (String) -> Void, onSave: @escaping (String) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.initialText = initialText
    self.lastRecord = lastRecord
    self.isSaving = isSaving
    self.saveFailed = saveFailed
    self.onChange = onChange
    self.onSave = onSave
    self.onCancel = onCancel
    _input = State(initialValue: NumberPadTextInput(value: initialText, field: .weight))
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      Capsule().fill(Color.MeetPR.borderStrong).frame(width: 32, height: 4)
      HStack {
        Text(StudentStrings.localized(.weightTodayTitle))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .bold))
        Spacer()
        Text(Date().formatted(.dateTime.month().day().weekday(.abbreviated)))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      HStack(alignment: .center) {
        Text(input.text.isEmpty ? "—" : input.text)
          .font(.system(size: 40, weight: .bold, design: .monospaced))
          .minimumScaleFactor(0.6)
          .lineLimit(1)
          .accessibilityIdentifier("bodyWeight.pad.value")
        Rectangle().fill(Color.MeetPR.goldText).frame(width: 2, height: 36)
        Text("kg").font(.body).foregroundStyle(Color.MeetPR.textSecondary)
        Spacer(minLength: 0)
        if let lastRecord {
          Text(
            StudentStrings.replacing(
              .weightLastValue,
              values: [
                lastRecord.weightKg.formatted(.number.precision(.fractionLength(1))),
                BodyWeightDay.shortDate(lastRecord.recordedOn),
              ])
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
        }
      }
      .padding(MeetPRSpacing.space3)
      .background(Color.MeetPR.bgInset, in: .rect(cornerRadius: 14))
      .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.MeetPR.goldText, lineWidth: 1.5) }
      Text(StudentStrings.localized(saveFailed ? .weightSaveFailed : .weightTodayHelp))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(saveFailed ? Color.MeetPR.danger : Color.MeetPR.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      BodyWeightPadGrid(
        input: $input, isSaving: isSaving,
        onSave: { onSave(input.committedText) }, onCancel: onCancel)
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard, in: .rect(topLeadingRadius: 22, topTrailingRadius: 22))
    .foregroundStyle(Color.MeetPR.textPrimary)
    .onChange(of: input.text) { _, value in
      feedback += 1
      onChange(value)
    }
    .sensoryFeedback(.selection, trigger: feedback)
    .accessibilityAddTraits(.isModal)
    .accessibilityAction(.escape, onCancel)
  }
}

private struct BodyWeightPadGrid: View {
  @Binding var input: NumberPadTextInput
  let isSaving: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 8) {
        VStack(spacing: 8) {
          ForEach(0..<3) { row in
            HStack(spacing: 8) {
              ForEach(1..<4) { column in
                BodyWeightPadKey(title: String(row * 3 + column)) {
                  input.append(String(row * 3 + column))
                }
              }
            }
          }
          HStack(spacing: 8) {
            BodyWeightPadKey(title: ".") { input.append(".") }
            BodyWeightPadKey(title: "0") { input.append("0") }
            BodyWeightPadKey(title: StudentStrings.localized(.weightDismiss), action: onCancel)
          }
        }
        .frame(maxWidth: .infinity)
        VStack(spacing: 8) {
          BodyWeightPadKey(title: "⌫", action: { input.deleteLast() })
            .accessibilityLabel(StudentStrings.localized(.bodyWeightDelete))
          Button(action: onSave) {
            Group {
              if isSaving { ProgressView() } else { Text(StudentStrings.localized(.weightDone)) }
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.ctaText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
              LinearGradient(
                colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.goldGradientEnd],
                startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: 14))
          }
          .disabled(BodyWeightEntryModel.kilograms(input.committedText) == nil || isSaving)
          .accessibilityIdentifier("bodyWeight.pad.save")
        }
        .frame(width: (geometry.size.width - 24) / 4)
      }
    }
    .frame(height: 232)
    .disabled(isSaving)
  }
}

private struct BodyWeightPadKey: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(
          .MeetPR.mono(
            size: title.count > 1 ? MeetPRFontMetrics.size13 : MeetPRFontMetrics.size21,
            weight: .semibold)
        )
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.MeetPR.surfaceKey, in: .rect(cornerRadius: 14))
    }
  }
}

struct BodyWeightEntryOverlay: View {
  let model: BodyWeightEntryModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    if model.isPresented {
      ZStack(alignment: .bottom) {
        Button(action: model.cancel) {
          Color.black.opacity(colorScheme == .dark ? 0.55 : 0.28)
            .contentShape(.rect).ignoresSafeArea()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(StudentStrings.localized(.weightDismiss))
        BodyWeightNumberPad(
          initialText: model.previewText, lastRecord: model.latest,
          isSaving: model.isSaving, saveFailed: model.saveFailed,
          onChange: { model.previewText = $0 },
          onSave: { text in Task { _ = await model.save(text) } },
          onCancel: model.cancel)
      }
    }
  }
}
