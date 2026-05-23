import SwiftUI

@MainActor
public struct DesignSystemDemo: View {
  @State private var selectedScheme = DemoScheme.system
  @State private var phone = "+86 138 0000 0000"
  @State private var code = "284913"
  @State private var weight = 142.5
  @State private var unit = MeetPRWeightUnit.kg
  @State private var rpe = 8.5

  public init() {}

  public var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        DemoHeader(selectedScheme: $selectedScheme)
        ColorTokenCatalog()
        TypographyCatalog()
        GeometryTokenCatalog()
        ButtonCatalog()
        CardCatalog()
        LabelCatalog()
        BadgeCatalog()
        InputCatalog(phone: $phone, code: $code, weight: $weight, unit: $unit, rpe: $rpe)
        ListRowCatalog()
      }
      .padding(MeetPRSpacing.base)
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bg)
    .preferredColorScheme(selectedScheme.colorScheme)
  }
}

private enum DemoScheme: String, CaseIterable, Identifiable {
  case system = "System"
  case light = "Light"
  case dark = "Dark"

  var id: String { rawValue }

  var colorScheme: ColorScheme? {
    switch self {
    case .system:
      nil
    case .light:
      .light
    case .dark:
      .dark
    }
  }
}

@MainActor
private struct DemoHeader: View {
  @Binding var selectedScheme: DemoScheme

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
      Eyebrow("DESIGN SYSTEM")
      Text("MeetPR Foundation")
        .font(Font.MeetPR.title1)
        .foregroundStyle(Color.MeetPR.fgPrimary)

      Picker("Color scheme", selection: $selectedScheme) {
        ForEach(DemoScheme.allCases) { scheme in
          Text(scheme.rawValue).tag(scheme)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityLabel("Color scheme")
      .accessibilityHint("Switches the catalog between system, light, and dark mode.")
    }
  }
}

@MainActor
private struct ColorTokenCatalog: View {
  var body: some View {
    DemoSection(title: "COLOR TOKENS") {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: MeetPRSpacing.sm)]) {
        DemoColorSwatch(name: "brandRed", color: Color.MeetPR.brandRed, value: "#E5221E")
        DemoColorSwatch(name: "brandRedPress", color: Color.MeetPR.brandRedPress, value: "#B81A17")
        DemoColorSwatch(name: "brandRedSoft", color: Color.MeetPR.brandRedSoft, value: "12/8%")
        DemoColorSwatch(name: "green", color: Color.MeetPR.green, value: "#1FB358")
        DemoColorSwatch(name: "greenSoft", color: Color.MeetPR.greenSoft, value: "14%")
        DemoColorSwatch(name: "amber", color: Color.MeetPR.amber, value: "#E0A810")
        DemoColorSwatch(name: "amberSoft", color: Color.MeetPR.amberSoft, value: "14%")
        DemoColorSwatch(name: "bg", color: Color.MeetPR.bg, value: "dynamic")
        DemoColorSwatch(name: "surface1", color: Color.MeetPR.surface1, value: "dynamic")
        DemoColorSwatch(name: "surface2", color: Color.MeetPR.surface2, value: "dynamic")
        DemoColorSwatch(name: "surface3", color: Color.MeetPR.surface3, value: "dynamic")
        DemoColorSwatch(name: "border", color: Color.MeetPR.border, value: "dynamic")
        DemoColorSwatch(name: "borderStrong", color: Color.MeetPR.borderStrong, value: "dynamic")
        DemoColorSwatch(name: "fgPrimary", color: Color.MeetPR.fgPrimary, value: "dynamic")
        DemoColorSwatch(name: "fgSecondary", color: Color.MeetPR.fgSecondary, value: "dynamic")
        DemoColorSwatch(name: "fgTertiary", color: Color.MeetPR.fgTertiary, value: "dynamic")
        DemoColorSwatch(name: "fgDisabled", color: Color.MeetPR.fgDisabled, value: "35%")
      }
    }
  }
}

@MainActor
private struct DemoColorSwatch: View {
  let name: String
  let color: Color
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .fill(color)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.md)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
        .frame(height: 56)

      Text(name.uppercased())
        .font(Font.MeetPR.caption)
        .tracking(0.66)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)

      Text(value)
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
    .padding(MeetPRSpacing.sm)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }
}

@MainActor
private struct TypographyCatalog: View {
  var body: some View {
    DemoSection(title: "TYPOGRAPHY") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        Text("Train under tension.")
          .font(Font.MeetPR.displayHero)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("Coach Dashboard")
          .font(Font.MeetPR.title1)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("This Week")
          .font(Font.MeetPR.title2)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("Squat - Top Set")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("Squat W3D1 published. Notify Chen Lei?")
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("Synced 3 minutes ago - 2 athletes overdue")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Text("14:23 - session 4 of 16")
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
        Text("SQUAT STANDARD")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.brandRed)
        StatBlock(label: "Squat 1RM", value: "200", unit: "KG")
      }
    }
  }
}

@MainActor
private struct GeometryTokenCatalog: View {
  var body: some View {
    DemoSection(title: "SPACING / RADIUS / MOTION") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        HStack(alignment: .bottom, spacing: MeetPRSpacing.base) {
          DemoBlock(label: "XS", size: MeetPRSpacing.xs)
          DemoBlock(label: "SM", size: MeetPRSpacing.sm)
          DemoBlock(label: "MD", size: MeetPRSpacing.md)
          DemoBlock(label: "BASE", size: MeetPRSpacing.base)
          DemoBlock(label: "LG", size: MeetPRSpacing.lg)
          DemoBlock(label: "XL", size: MeetPRSpacing.xl)
        }

        HStack(spacing: MeetPRSpacing.md) {
          DemoRadius(label: "SM", radius: MeetPRRadius.sm)
          DemoRadius(label: "MD", radius: MeetPRRadius.md)
          DemoRadius(label: "LG", radius: MeetPRRadius.lg)
          DemoRadius(label: "XL", radius: MeetPRRadius.xl)
          DemoRadius(label: "PILL", radius: MeetPRRadius.pill)
        }

        Text("EASE IOS - 0.32, 0.72, 0, 1 - 240MS")
          .font(Font.MeetPR.caption)
          .tracking(0.66)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
  }
}

@MainActor
private struct DemoBlock: View {
  let label: String
  let size: CGFloat

  var body: some View {
    VStack(spacing: MeetPRSpacing.xs) {
      Rectangle()
        .fill(label == "XS" ? Color.MeetPR.brandRed : Color.MeetPR.fgPrimary)
        .frame(width: size, height: size)
      Text(label)
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
  }
}

@MainActor
private struct DemoRadius: View {
  let label: String
  let radius: CGFloat

  var body: some View {
    VStack(spacing: MeetPRSpacing.xs) {
      RoundedRectangle(cornerRadius: radius)
        .fill(Color.MeetPR.surface2)
        .overlay {
          RoundedRectangle(cornerRadius: radius)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
        .frame(width: label == "PILL" ? 72 : 44, height: 44)
      Text(label)
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
  }
}

@MainActor
private struct ButtonCatalog: View {
  var body: some View {
    DemoSection(title: "BUTTONS") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        DemoComponentCaption("COMP-BUTTONS.HTML")
        FlowLayout {
          PrimaryButton("Save Mesocycle") {}
          SecondaryButton("Discard") {}
          DangerButton("Revoke Access") {}
          IconButton {}
        }
      }
    }
  }
}

@MainActor
private struct CardCatalog: View {
  var body: some View {
    DemoSection(title: "CARDS") {
      VStack(spacing: MeetPRSpacing.base) {
        DemoComponentCaption("COMP-CARDS.HTML / ANATOMY-CARD.HTML")
        Card(accessibilityLabel: "Training card") {
          VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
            Eyebrow("SQUAT W3D1")
            Text("Top Set + 3 Backoff")
              .font(Font.MeetPR.headline)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text("4 sets - about 28 min")
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }
        ElevatedCard(accessibilityLabel: "System suggestion card") {
          VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
            Eyebrow("SYSTEM //")
            Text("Detected RPE 10 across 3 sessions.")
              .font(Font.MeetPR.bodyEmphasis)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text("Reduce W4 backoff by 5%?")
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }
      }
    }
  }
}

@MainActor
private struct LabelCatalog: View {
  var body: some View {
    DemoSection(title: "LABELS") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        DemoComponentCaption("COMP-STAT-EYEBROW.HTML")
        Eyebrow("PROTOCOL 01")
        HStack(alignment: .bottom, spacing: MeetPRSpacing.lg) {
          StatBlock(label: "Squat Standard", value: "320", unit: "KG")
          StatBlock(label: "Bench", value: "200", unit: "KG")
        }
      }
    }
  }
}

@MainActor
private struct BadgeCatalog: View {
  var body: some View {
    DemoSection(title: "BADGES") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        DemoComponentCaption("COMP-BADGES.HTML")
        FlowLayout {
          PRBadge(.newPR)
          PRBadge(.pr)
          StatusBadge(status: .ready)
          StatusBadge(status: .pending)
          StatusBadge(status: .overdue)
          StatusBadge(status: .completed)
          StatusBadge(status: .live)
        }
      }
    }
  }
}

@MainActor
private struct InputCatalog: View {
  @Binding var phone: String
  @Binding var code: String
  @Binding var weight: Double
  @Binding var unit: MeetPRWeightUnit
  @Binding var rpe: Double

  var body: some View {
    DemoSection(title: "INPUTS") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        DemoComponentCaption("COMP-TEXTFIELD.HTML")
        MeetPRTextField("Phone", text: $phone)
        MeetPRTextField("Verification Code", text: $code, isMonospaced: true)
        MeetPRTextField(
          "Code",
          text: .constant("000000"),
          errorMessage: "Code expired. Request a new one.",
          isMonospaced: true
        )

        DemoComponentCaption("COMP-NUMERIC.HTML")
        NumericInput(value: $weight, unit: $unit)

        DemoComponentCaption("COMP-RPE-SLIDER.HTML")
        RPESlider(value: $rpe)
      }
    }
  }
}

@MainActor
private struct ListRowCatalog: View {
  var body: some View {
    DemoSection(title: "LIST ROW") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        DemoComponentCaption("COMP-LISTROW.HTML")
        VStack(spacing: 0) {
          MeetPRListRow(
            title: "Chen Lei",
            subtitle: "W3D1 - last logged 2h ago",
            status: .ready,
            showsPRBadge: true
          ) {}
          Divider().background(Color.MeetPR.border)
          MeetPRListRow(title: "Ma Wei", subtitle: "W3D1 - queued", status: .pending) {}
          Divider().background(Color.MeetPR.border)
          MeetPRListRow(title: "Yan Bo", subtitle: "W2D3 - 5 days behind", status: .overdue) {}
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.lg)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
      }
    }
  }
}

@MainActor
private struct DemoSection<Content: View>: View {
  let title: String
  let content: Content

  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
      Text(title)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.brandRed)
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

@MainActor
private struct DemoComponentCaption: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(Font.MeetPR.caption)
      .tracking(0.66)
      .foregroundStyle(Color.MeetPR.fgTertiary)
  }
}

@MainActor
private struct FlowLayout<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: MeetPRSpacing.sm) {
        content
      }
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        content
      }
    }
  }
}

#Preview("DesignSystemDemo Dark") {
  DesignSystemDemo()
    .preferredColorScheme(.dark)
}

#Preview("DesignSystemDemo Light") {
  DesignSystemDemo()
    .preferredColorScheme(.light)
}
