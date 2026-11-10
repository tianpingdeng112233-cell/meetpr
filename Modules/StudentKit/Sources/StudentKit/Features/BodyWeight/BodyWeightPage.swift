import DesignSystem
import RepositoryContracts
import SwiftUI

struct BodyWeightPage: View {
  let model: BodyWeightViewModel
  let studentID: UUID
  let onboarding: (any OnboardingRepository)?
  @State private var showsEditor = false
  @State private var selectedRecord: BodyWeightRecord?
  @State private var confirmsDelete = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
        if model.isFailed {
          ProgressRetryRow { Task { await model.load() } }
        } else if model.isLoaded {
          BodyWeightChartCard(presentation: model.presentation, range: model.range) {
            switch model.range {
            case .thirtyDays: model.range = .ninetyDays
            case .ninetyDays: model.range = .all
            case .all: model.range = .thirtyDays
            }
          }
          GoldCTA(
            StudentStrings.localized(
              model.presentation.hasToday ? .bodyWeightUpdate : .bodyWeightLog),
            sub: nil, icon: .none, isDisabled: model.deletingDate != nil
          ) { showsEditor = true }
          Text(StudentStrings.localized(.bodyWeightRecords))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textSecondary)
          BodyWeightRecordsList(
            records: model.presentation.records, deletingDate: model.deletingDate,
            onDelete: {
              selectedRecord = $0
              confirmsDelete = true
            })
          if model.deletionFailed {
            HStack {
              Text(StudentStrings.localized(.bodyWeightDeleteFailed))
              Button(StudentStrings.localized(.trainingHistoryView023)) {
                Task { _ = await model.retryDelete() }
              }
              .frame(minHeight: MeetPRSpacing.minimumHitTarget)
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textSecondary)
          }
        } else {
          ProgressView().frame(maxWidth: .infinity)
        }
      }
      .padding(MeetPRSpacing.pageHorizontal)
    }
    .background(Color.MeetPR.bgBase)
    .navigationTitle(StudentStrings.localized(.bodyWeightTitle))
    #if os(iOS)
      .toolbar(.visible, for: .navigationBar)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .navigationDestination(isPresented: $showsEditor) {
      if let onboarding {
        DashboardProfileEditor(kind: .weight, studentID: studentID, onboarding: onboarding)
      }
    }
    .onChange(of: showsEditor) { previous, current in
      if previous && !current { Task { await model.load() } }
    }
    .alert(
      StudentStrings.localized(.bodyWeightDeleteConfirm), isPresented: $confirmsDelete,
      presenting: selectedRecord
    ) { record in
      Button(StudentStrings.localized(.bodyWeightDelete), role: .destructive) {
        Task { _ = await model.delete(record) }
      }
      Button(StudentStrings.localized(.accountSecuritySheets013), role: .cancel) {}
    }
    .refreshable { await model.load() }
    .task { await model.load() }
  }
}
