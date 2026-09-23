import DevilKit
import SwiftUI

/// Who stopped the clock.
///
/// Worth saying. A pause nobody remembers causing is a knocked scale or a
/// stray press, and knowing which end it came from is the difference between
/// carrying on and looking at the counter.
enum PauseSource {
  case phone
  case scale
}

/// What a held brew says.
///
/// The clock stops and the kettle does not, so a long hold leaves the recipe's
/// temperatures behind even though the times still line up. Better said once,
/// here, than discovered in the cup.
struct HeldNote: View {
  let source: PauseSource

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        if source == .scale {
          Image(systemName: "scalemass.fill")
        }
        Text(source == .scale ? "Paused on the scale" : "Paused")
      }
      .font(.title2.weight(.semibold))
      .foregroundStyle(source == .scale ? Color.orange : .primary)
      Text("The clock has stopped. The kettle has not.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 16))
  }
}

#Preview {
  NavigationStack {
    TimerView(
      recipe: .switchWaterAndTempManaged,
      settings: BrewSettings(),
      brew: RunningBrew(tappedAt: .now),
      scale: ScaleConnection(),
      probe: ProbeConnection(),
      notesFor: .constant(nil)
    )
  }
}
