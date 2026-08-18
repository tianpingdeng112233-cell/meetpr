import SwiftUI

@MainActor
public struct InitialAvatar: View {
  private let name: String
  private let size: CGFloat

  public init(_ name: String, size: CGFloat = 44) {
    self.name = name
    self.size = size
  }

  public var body: some View {
    Text(Self.initials(from: name))
      .font(Font.MeetPR.bodyEmphasis)
      .foregroundStyle(Color.MeetPR.textPrimary)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .frame(width: size, height: size)
      .background(Color.MeetPR.surfaceKey)
      .clipShape(.circle)
      .overlay {
        Circle()
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .accessibilityHidden(true)
  }

  private static func initials(from name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "?" }

    let parts = trimmed.split(whereSeparator: \.isWhitespace)
    if parts.count > 1 {
      return parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
    return String(trimmed.prefix(2)).uppercased()
  }
}

#Preview("InitialAvatar") {
  HStack(spacing: MeetPRSpacing.base) {
    InitialAvatar(DesignSystemStrings.previewInitials)
    InitialAvatar("Chen Lei")
    InitialAvatar("")
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}
