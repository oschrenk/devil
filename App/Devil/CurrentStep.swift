import DevilKit
import SwiftUI

/// What to do now, large enough to read from across the counter.
struct CurrentStep: View {
  let recipe: Recipe
  let progress: BrewProgress

  /// Closed to start with, and kept across brews rather than reset each time.
  /// Whether the instructions are wanted is a property of how well the recipe
  /// is known, not of today, and by now the recipe is known.
  @AppStorage("stepInstructionsShown") private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Text(progress.step.title)
          .font(.title2.weight(.semibold))
        Spacer()
        SwitchBadge(position: progress.step.switchPosition)
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }

      if isExpanded {
        ForEach(recipe.instructions(for: progress.step), id: \.self) { line in
          InstructionRow(text: line)
        }
      }

      if let seconds = progress.secondsUntilNextStep, let next = progress.nextStep {
        Text("\(next.title) in \(seconds)s")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 16))
    // The whole card, not the chevron. A target the size of a fingertip is
    // the wrong one to aim at with a kettle in the other hand.
    .contentShape(.rect)
    .onTapGesture { withAnimation(.snappy) { isExpanded.toggle() } }
  }
}

/// The switch position is the one thing that ruins a brew rather than delaying
/// it, so it gets colour and a shape rather than a line of text.
private struct SwitchBadge: View {
  let position: SwitchPosition

  var body: some View {
    Label(
      position == .open ? "Open" : "Closed",
      systemImage: position == .open ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    )
    .font(.headline)
    .foregroundStyle(position == .open ? .green : .orange)
  }
}

/// One line of what to do.
///
/// The bullet is a `Text`, not an SF Symbol. `.firstTextBaseline` puts an
/// image's bottom edge on the baseline, so a small dot sits low against the
/// words. A glyph carries the font's own metrics and lines up on its own.
private struct InstructionRow: View {
  let text: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text("\u{2022}")
        .foregroundStyle(.secondary)
        .frame(width: 10, alignment: .leading)
      Text(text)
    }
    .font(.title3)
  }
}
