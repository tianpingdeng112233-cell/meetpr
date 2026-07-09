import DesignSystem
import SwiftUI

/// Solo review entry (spec 051 §1): same submit machine as the coached
/// summary, honest solo copy — there is no coach to promise to.
@available(iOS 17.0, macOS 14.0, *)
struct SoloReviewSheet: View {
  @Bindable var viewModel: SessionReviewSubmitViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("今天练得怎么样?", text: $viewModel.feeling, axis: .vertical)
            .lineLimit(2...5)
        } footer: {
          Text("记录你的状态,曲线之外的另一半")
        }

        switch viewModel.state {
        case .saved:
          Label("已保存", systemImage: "checkmark.circle.fill")
            .foregroundStyle(Color.MeetPR.green)
        case .failed(let message):
          Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.MeetPR.brandRed)
        case .idle, .submitting:
          EmptyView()
        }

        Button {
          Task {
            await viewModel.submit()
            if viewModel.state == .saved { dismiss() }
          }
        } label: {
          Text(viewModel.state == .submitting ? "保存中…" : "保存回顾")
            .frame(maxWidth: .infinity)
            .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.MeetPR.brandRed)
        .disabled(!viewModel.canSubmit)
        .accessibilityIdentifier("solo.review.submit")
      }
      .navigationTitle("今天的感受")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .task { await viewModel.load() }
    }
  }
}
