import DevilKit
import SwiftUI

/// The whole recipe, read before the water starts moving.
struct Schedule: View {
  let recipe: Recipe
  let progress: BrewProgress

  /// Scales with the reader's text size, so the clock column never squeezes
  /// `0:00` onto two lines. The step title gives way instead.
  @ScaledMetric private var timeWidth: Double = 46

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(recipe.steps.enumerated()), id: \.element.start) { index, step in
        HStack {
          Text(step.start.formatted)
            .monospacedDigit()
            .fixedSize()
            .frame(minWidth: timeWidth, alignment: .leading)
          Text(step.title)
            .lineLimit(2)
          Spacer(minLength: 4)
          if step.poured > 0 {
            Text(Format.grams(step.poured))
              .fixedSize()
          }
        }
        .font(.subheadline)
        .foregroundStyle(index == progress.stepIndex ? .primary : .tertiary)
        .fontWeight(index == progress.stepIndex ? .semibold : .regular)
        .padding(.vertical, 6)
      }
    }
    .padding(.bottom)
  }
}
