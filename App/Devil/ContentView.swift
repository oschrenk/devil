import DevilKit
import SwiftUI

/// The one screen, still a placeholder.
///
/// `DEVIL-02` moved the numbers into `DevilKit` and left the interface alone,
/// so this shows the headline figures and nothing else. `DEVIL-03` and
/// `DEVIL-04` build the real screens.
struct ContentView: View {
  private let recipe = Recipe.switchWaterAndTempManaged

  private var headline: String {
    "\(Int(recipe.dose)) g · \(Int(recipe.waterThroughBed)) g · \(Int(recipe.brewTemperature)) °C"
  }

  var body: some View {
    VStack(spacing: 8) {
      Text(recipe.brewer)
        .font(.largeTitle.weight(.semibold))
      Text(headline)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text(recipe.totalTime.formatted)
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(.tertiary)
    }
  }
}

#Preview {
  ContentView()
}
