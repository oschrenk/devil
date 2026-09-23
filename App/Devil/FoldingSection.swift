import SwiftUI

/// A form section that folds down to one line.
///
/// Most of this screen is settled. The grinder, the papers and the preheat
/// amounts are the same every morning, and a screenful of them stands between
/// you and the only control that changes, which is how many people are
/// drinking. Closed, a section shows what it adds up to; open, it shows the
/// rows that produce that number.
///
/// The content closure is handed the open state rather than being hidden
/// wholesale, so a section can pin a row that stays visible either way.
///
/// Open or closed is remembered, and not per brew. Whether you want to see the
/// grind is a fact about how well you know the recipe.
struct FoldingSection<Content: View>: View {
  private let title: String
  private let summary: String
  private let footer: String?
  private let content: (Bool) -> Content

  @AppStorage private var isOpen: Bool

  init(
    _ title: String,
    summary: String = "",
    footer: String? = nil,
    openByDefault: Bool = false,
    @ViewBuilder content: @escaping (Bool) -> Content
  ) {
    self.title = title
    self.summary = summary
    self.footer = footer
    self.content = content
    _isOpen = AppStorage(wrappedValue: openByDefault, "section.\(title)")
  }

  var body: some View {
    Section {
      content(isOpen)
    } header: {
      Button {
        withAnimation(.snappy) { isOpen.toggle() }
      } label: {
        HStack(spacing: 8) {
          Text(title)
          Spacer()
          if !isOpen, !summary.isEmpty {
            // `textCase(nil)` because a header uppercases its content, and a
            // summary is a measurement rather than a label. Smaller than the
            // title, because it answers the title rather than competing with
            // it. `.caption` still scales with Dynamic Type.
            Text(summary)
              .textCase(nil)
              .font(.caption)
          }
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(isOpen ? 90 : 0))
            .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
    } footer: {
      if isOpen, let footer {
        Text(footer)
      }
    }
  }
}
