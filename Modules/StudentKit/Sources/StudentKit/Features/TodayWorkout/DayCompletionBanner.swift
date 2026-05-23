import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DayCompletionBanner: View {
  let totalSets: Int

  var body: some View {
    HStack {
      Image(systemName: "checkmark.seal.fill")
      Text("今日完成 · 总组数 \(totalSets) / 完成 \(totalSets)")
      Spacer()
    }
    .font(.headline)
    .padding()
    .foregroundStyle(.white)
    .background(Color.green)
    .clipShape(.rect(cornerRadius: 8))
  }
}
