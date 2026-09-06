import DevilKit
import SwiftUI

struct ContentView: View {
  @State private var settings = BrewSettings.one

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
          LabelledValue(label: "Ratio", value: "1 : \(recipe.brewRatio.oneDecimal)")
          LabelledValue(label: "Finish", value: recipe.finish?.formatted ?? "not timed")
        }
      }
      .navigationTitle(recipe.brewer)
      .navigationBarTitleDisplayMode(.inline)
      .monospacedDigit()
    }
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
  /// Whole grams read as "50 g"; halves as "112.5 g". Trailing zeros are noise
  /// on a scale that only ever shows one decimal.
  var grams: String {
    "\(oneDecimal) g"
  }

  var degrees: String {
    "\(oneDecimal) °C"
  }

  var oneDecimal: String {
    self == rounded() ? "\(Int(self))" : String(describing: (self * 10).rounded() / 10)
  }
}

#Preview {
  ContentView()
}
