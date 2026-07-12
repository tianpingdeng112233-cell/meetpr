import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Solo 训练 tab (spec 047 §3): read-only month-grouped session history —
/// the plan calendar's replacement. Editing stays on the 今天 tab
/// (扫视态 vs 编辑态 split).
@available(iOS 17.0, macOS 14.0, *)
public struct SoloHistoryView: View {
  private let studentID: UUID
  private let exerciseNames: [UUID: String]
  @State private var viewModel: TrainingHistoryViewModel
  @State private var selectedDay: TrainingHistoryViewModel.HistoryDaySession?

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository,
    onboarding: any OnboardingProfileReading,
    sessionReviews: (any SessionReviewRepository)? = nil,
    catalog: [Exercise] = []
  ) {
    self.studentID = studentID
    self.exerciseNames = Dictionary(
      catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    self._viewModel = State(
      initialValue: TrainingHistoryViewModel(
        plans: plans, logs: logs, onboarding: onboarding,
        reviews: sessionReviews, e1rm: e1rm, mode: .selfTrain, catalog: catalog))
  }

  public var body: some View {
    NavigationStack {
      Group {
        switch viewModel.state {
        case .idle, .loading:
          ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
          VStack(spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.fgSecondary)
            Button("重试") {
              Task { await viewModel.load(studentID: studentID) }
            }
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.brandRed)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
          if viewModel.soloMonths.isEmpty {
            VStack(spacing: 8) {
              Text("还没有训练记录")
                .font(.headline)
              Text("去「今天」记下第一组,这里就会开始累积")
                .font(.footnote)
                .foregroundStyle(Color.MeetPR.fgSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            SoloHistoryListView(
              months: viewModel.soloMonths,
              reviews: viewModel.reviewsByDay
            ) { day in
              selectedDay = day
            }
          }
        }
      }
      .background(Color.MeetPR.bg)
      .navigationTitle("历史")
      .task { await loadIfNeeded() }
      .refreshable { await viewModel.load(studentID: studentID) }
      .sheet(item: $selectedDay) { day in
        SoloDayDetailSheet(
          day: day,
          logs: dayLogs(for: day),
          review: viewModel.reviewsByDay[day.dayKey],
          exerciseNames: exerciseNames
        )
        .presentationDetents([.medium, .large])
      }
    }
  }

  private func loadIfNeeded() async {
    if viewModel.state == .idle {
      await viewModel.load(studentID: studentID)
    }
  }

  private func dayLogs(for day: TrainingHistoryViewModel.HistoryDaySession) -> [StudentSetLog] {
    guard case .loaded(_, let logs) = viewModel.state else { return [] }
    return
      logs
      .filter { $0.completed && Calendar.current.isDate($0.loggedAt, inSameDayAs: day.date) }
      .sorted { $0.loggedAt < $1.loggedAt }
  }
}

/// Embeddable month-section list — the 成长 tab's detailed history reuses it
/// in solo mode (no plan weeks to group by).
@available(iOS 17.0, macOS 14.0, *)
struct SoloHistoryListView: View {
  let months: [TrainingHistoryViewModel.SoloHistoryMonth]
  let reviews: [String: SessionReview]
  var onSelect: ((TrainingHistoryViewModel.HistoryDaySession) -> Void)?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        ForEach(months) { month in
          VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
            Text(month.title)
              .font(Font.MeetPR.headline)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            ForEach(month.days) { day in
              dayCard(day)
            }
          }
        }
      }
      .padding(MeetPRSpacing.md)
    }
    .scrollContentBackground(.hidden)
  }

  @ViewBuilder
  private func dayCard(_ day: TrainingHistoryViewModel.HistoryDaySession) -> some View {
    Button {
      onSelect?(day)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            Text(StudentFormatting.dayMonthFormatter.string(from: day.date))
              .font(Font.MeetPR.bodyEmphasis)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text(StudentFormatting.weekdayFormatter.string(from: day.date))
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text("\(day.setCount) 组")
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.fgSecondary)
            if let best = day.bestE1RMKg {
              // 「当日峰值」not「最佳」— this is this session's raw peak e1RM, a
              // per-day figure distinct from the growth tab's smoothed rolling
              // trend (P0-5 消歧: 两处口径不同,各安其位).
              Text("当日峰值 e1RM \(StudentFormatting.kilograms(best)) kg")
                .font(Font.MeetPR.caption)
                .foregroundStyle(Color.MeetPR.brandRed)
            }
          }
        }
        Text(day.exerciseNames.joined(separator: " · "))
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)
        if let review = reviews[day.dayKey] {
          Text("「\(review.feeling)」")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.md)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("solo.history.day.\(day.dayKey)")
  }
}

/// Read-only day detail: the day's sets grouped by exercise, 重量×次数@RPE.
@available(iOS 17.0, macOS 14.0, *)
private struct SoloDayDetailSheet: View {
  let day: TrainingHistoryViewModel.HistoryDaySession
  let logs: [StudentSetLog]
  let review: SessionReview?
  let exerciseNames: [UUID: String]

  var body: some View {
    NavigationStack {
      List {
        if let review {
          Section("当日回顾") {
            Text("「\(review.feeling)」")
              .font(.subheadline)
          }
        }
        ForEach(exerciseOrder, id: \.self) { exerciseID in
          Section(exerciseNames[exerciseID] ?? "动作") {
            ForEach(logs.filter { $0.exerciseID == exerciseID }, id: \.id) { log in
              Text(setLine(log))
                .font(.system(size: 15).monospacedDigit())
            }
          }
        }
      }
      .navigationTitle(StudentFormatting.dayMonthFormatter.string(from: day.date))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }

  private var exerciseOrder: [UUID] {
    var seen: Set<UUID> = []
    return logs.compactMap { log in
      guard let id = log.exerciseID else { return nil }
      return seen.insert(id).inserted ? id : nil
    }
  }

  private func setLine(_ log: StudentSetLog) -> String {
    let weight = NSDecimalNumber(decimal: log.weightKg).doubleValue
    var line = "\(StudentFormatting.kilograms(weight)) kg × \(log.reps)"
    if let rpe = log.rpe {
      line += " @\(rpe)"
    }
    return line
  }
}
