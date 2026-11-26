import DesignSystem
import SwiftUI

struct WorkoutResumePrompt: Identifiable {
  let id: UUID
  let planID: UUID
  let code: String
  let lastOpened: Date
  var today: Date
  let recorded: Int
  let total: Int

  func asOf(_ newToday: Date) -> Self {
    var refreshed = self
    refreshed.today = max(lastOpened, newToday)
    return refreshed
  }

  var days: [Date] {
    let calendar = WorkoutDatePolicy.deviceCalendar
    let count = calendar.dateComponents([.day], from: lastOpened, to: today).day ?? 0
    return (0...max(0, count)).compactMap {
      calendar.date(byAdding: .day, value: $0, to: lastOpened)
    }
  }
}

struct WorkoutResumeSheet: View {
  let prompt: WorkoutResumePrompt
  let lockedDate: Date?
  let onComplete: (Date) async -> Bool
  let onContinue: () -> Void
  @State private var selected: Date
  @State private var editing = false
  @State private var sending = false
  @State private var failed = false

  init(
    prompt: WorkoutResumePrompt, lockedDate: Date?, onComplete: @escaping (Date) async -> Bool,
    onContinue: @escaping () -> Void
  ) {
    self.prompt = prompt
    self.lockedDate = lockedDate
    self.onComplete = onComplete
    self.onContinue = onContinue
    _selected = State(initialValue: lockedDate ?? prompt.lastOpened)
  }

  var body: some View {
    ViewThatFits(in: .vertical) {
      content
      ScrollView { content }
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 20)
    .background(Color.MeetPR.surfaceCard)
    .presentationDragIndicator(.visible)
    .presentationDetents([
      .height(editing ? min(570, 355 + 60 * ceil(Double(prompt.days.count) / 3)) : 355), .large,
    ])
    .interactiveDismissDisabled()
    .onChange(of: prompt.today) { _, today in
      if selected > today, lockedDate == nil { selected = today }
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(StudentStrings.localized(.resumeTitle)).font(.title2.bold())
      Text(StudentStrings.replacing(.resumeDetail, values: [date(prompt.lastOpened)]))
        .foregroundStyle(Color.MeetPR.textSecondary)
      HStack {
        Text(prompt.code).bold()
        Text(
          prompt.recorded == 0
            ? StudentStrings.localized(.resumeEmpty)
            : StudentStrings.replacing(
              .resumeCount, values: [String(prompt.recorded), String(prompt.total)]))
      }.font(.subheadline)
      Divider()
      HStack {
        Text(StudentStrings.localized(.resumeDate))
        Text(date(selected)).bold()
        Spacer()
        if lockedDate == nil {
          Button(StudentStrings.localized(editing ? .resumeCollapse : .resumeChange)) {
            editing.toggle()
          }
          .foregroundStyle(Color.MeetPR.goldText)
          .frame(minHeight: 44)
        }
      }.font(.subheadline)
      if editing && lockedDate == nil { dates }
      Text(
        StudentStrings.localized(
          lockedDate != nil ? .resumeDateLocked : (failed ? .resumeRetry : .resumeEffect))
      )
      .font(.footnote).foregroundStyle(Color.MeetPR.textSecondary)
      Button {
        guard !sending else { return }
        sending = true
        Task {
          failed = !(await onComplete(selected))
          sending = false
        }
      } label: {
        ZStack {
          Text(StudentStrings.replacing(.resumeDone, values: [date(selected)])).opacity(
            sending ? 0 : 1)
          if sending { ProgressView().tint(.white) }
        }.frame(maxWidth: .infinity, minHeight: 48)
      }
      .buttonStyle(.plain).foregroundStyle(.white)
      .background(Color(red: 0.13, green: 0.10, blue: 0.07), in: .capsule)
      Button(StudentStrings.localized(.resumeContinue), action: onContinue)
        .buttonStyle(.plain).frame(maxWidth: .infinity, minHeight: 44)
    }
    .disabled(sending)
  }

  private var dates: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
      ForEach(prompt.days, id: \.self) { day in
        Button {
          selected = day
          editing = false
        } label: {
          VStack(spacing: 3) {
            Text(date(day)).font(.subheadline.bold())
            Text(dayHint(day)).font(.caption)
          }
          .frame(maxWidth: .infinity, minHeight: 52)
          .background(Color.MeetPR.bgBase, in: .rect(cornerRadius: 10))
          .overlay {
            if day == selected { RoundedRectangle(cornerRadius: 10).stroke(Color.MeetPR.goldText) }
          }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(day == selected ? .isSelected : [])
      }
    }
  }

  private func dayHint(_ day: Date) -> String {
    if day == prompt.lastOpened { return StudentStrings.localized(.resumeFirst) }
    if day == prompt.today { return StudentStrings.localized(.resumeToday) }
    if WorkoutDatePolicy.deviceCalendar.date(byAdding: .day, value: 1, to: day) == prompt.today {
      return StudentStrings.localized(.resumeYesterday)
    }
    return day.formatted(.dateTime.weekday(.abbreviated))
  }

  private func date(_ day: Date) -> String { day.formatted(.dateTime.month().day()) }
}
