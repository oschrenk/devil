import DevilKit
import SwiftUI

struct ContentView: View {
  @State private var settings = BrewSettings.one
  /// Non-nil while a brew is running.
  @State private var running: RunningBrew?

  private var recipe: Recipe {
    .switchWaterAndTempManaged(for: settings)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Brewing for") {
          Stepper(value: $settings.servings, in: BrewSettings.servingsRange) {
            LabelledValue(
              label: settings.servings == 1 ? "1 person" : "\(settings.servings) people",
              value: recipe.dose.grams
            )
          }
          Picker("Filter", selection: $settings.filter) {
            Text("Hario").tag(Filter.harioV60Size02)
            Text("Abaca").tag(Filter.abaca)
          }
          LabelledValue(label: "Grind", value: recipe.grindSetting)
        }

        Section("Temperature") {
          Stepper(value: $settings.brewTemperature, in: 85 ... 96, step: 0.5) {
            LabelledValue(label: "Kettle", value: recipe.brewTemperature.degrees)
          }
          Stepper(value: $settings.temperatureTarget, in: 65 ... 85, step: 1) {
            LabelledValue(label: "Last pour", value: recipe.temperatureTarget.degrees)
          }
        }

        Section("Kettle") {
          LabelledValue(label: "Tap", value: recipe.kettleFill.tap.grams)
          LabelledValue(label: "Beaker A", value: recipe.kettleFill.demineralized.grams)
            .accessibilityLabel("Beaker A, demineralized water for the kettle")
          LabelledValue(label: "Beaker B", value: recipe.cooler.amount.grams)
            .accessibilityLabel("Beaker B, cold demineralized water")
        }

        Section("Pours") {
          ForEach(recipe.steps, id: \.start) { step in
            StepRow(step: step)
          }
        }

        Section {
          LabelledValue(label: "Through the bed", value: recipe.waterThroughBed.grams)
          LabelledValue(label: "Ratio", value: "1 : \(Format.number(recipe.brewRatio))")
          LabelledValue(label: "Finish", value: recipe.finish?.formatted ?? "not timed")
        }

        Section {
          Button {
            running = RunningBrew(start: .now)
          } label: {
            Label("Start brewing", systemImage: "play.fill")
              .frame(maxWidth: .infinity)
          }
          .font(.headline)
        }
      }
      .navigationTitle(recipe.brewer)
      .navigationBarTitleDisplayMode(.inline)
      .monospacedDigit()
    }
    // A cover, not a push. A running brew is an activity rather than a place:
    // it should not sit on a navigation stack where a stray back-swipe ends it,
    // and a push destination inside a Form can deactivate on its own, which it
    // did, closing the timer part-way through a brew.
    .fullScreenCover(item: $running) { brew in
      NavigationStack {
        TimerView(recipe: recipe, start: brew.start)
      }
    }
  }
}

/// A brew in progress, identified by when it started.
///
/// The wrapper exists so the cover is presented once per brew. Keying it on a
/// bare `Date?` would rebuild the timer whenever the parent redrew.
struct RunningBrew: Identifiable, Equatable {
  let start: Date

  var id: Date {
    start
  }
}

/// A label on the left, a figure on the right, the way a spec sheet reads.
private struct LabelledValue: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      Text(value)
        .foregroundStyle(.secondary)
    }
  }
}

private struct StepRow: View {
  let step: Step

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(step.start.formatted)
        .foregroundStyle(.secondary)
        .frame(width: 44, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        Text(step.title)
        Text(step.switchPosition == .open ? "switch open" : "switch closed")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      Spacer()
      if step.poured > 0 {
        Text(step.poured.grams)
          .foregroundStyle(.secondary)
      }
    }
  }
}

private extension Double {
  var grams: String {
    Format.grams(self)
  }

  var degrees: String {
    Format.degrees(self)
  }
}

#Preview {
  ContentView()
}
