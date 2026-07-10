import CoreModels
import DesignSystem
import Observation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class ExportDataViewModel {
  public enum State: Equatable {
    case idle
    case generating
    case ready(URL)
    case failed(String)
  }

  public private(set) var state: State = .idle

  private let logs: any StudentTrainingLogRepository
  private let plans: any StudentPlanRepository
  private let now: @Sendable () -> Date

  public init(
    logs: any StudentTrainingLogRepository,
    plans: any StudentPlanRepository,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.logs = logs
    self.plans = plans
    self.now = now
  }

  public func export(studentID: UUID) async {
    guard state != .generating else { return }
    discardExport()
    state = .generating
    do {
      let start = Date(timeIntervalSince1970: 946_684_800)
      async let fetchedLogs = logs.fetchLogs(studentID: studentID, in: start...now())
      async let cycleDays = try? plans.fetchCycleDays(studentID: studentID)
      let allLogs = try await fetchedLogs
      let days = await cycleDays ?? []
      let names = Self.exerciseNames(from: days)
      let csv = TrainingLogCSVExporter.csv(logs: allLogs, names: names)
      let stamp = TrainingLogCSVExporter.compactDayString(now(), calendar: .current)
      let url = FileManager.default.temporaryDirectory
        .appending(path: "meetpr-training-log-\(stamp).csv")
      try Data(csv.utf8).write(to: url, options: .atomic)
      state = .ready(url)
    } catch {
      state = .failed("导出失败,请检查网络后重试")
    }
  }

  public func discardExport() {
    guard case .ready(let url) = state else { return }
    try? FileManager.default.removeItem(at: url)
    state = .idle
  }

  private static func exerciseNames(
    from days: [StudentPlanDay]
  ) -> [UUID: (name: String, nameEn: String?)] {
    Dictionary(
      days.flatMap(\.exercises).map {
        ($0.id, (name: $0.exercise.name, nameEn: $0.exercise.nameEn))
      },
      uniquingKeysWith: { first, _ in first }
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct ExportDataSheet: View {
  @Bindable var viewModel: ExportDataViewModel
  let studentID: UUID

  var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.lg) {
        switch viewModel.state {
        case .idle, .generating:
          ProgressView("正在整理你的全部训练数据…")
        case .failed(let message):
          Label(message, systemImage: "exclamationmark.triangle")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.brandRed)
          Button("重试") {
            Task { await viewModel.export(studentID: studentID) }
          }
        case .ready(let url):
          Label("CSV 已生成", systemImage: "checkmark.circle.fill")
            .foregroundStyle(Color.MeetPR.green)
          Text("包含全部训练组:日期/动作/重量/次数/RPE。")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          ShareLink(item: url) {
            Label("分享 / 存储", systemImage: "square.and.arrow.up")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.MeetPR.brandRed)
          .accessibilityIdentifier("account.export.share")
        }
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .navigationTitle("导出训练数据")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .task { await viewModel.export(studentID: studentID) }
    }
  }
}
