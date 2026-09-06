import DevilKit
import SwiftUI

/// What a brew starts from.
///
/// The main screen reads these when they change, so setting one here decides
/// what the next brew opens with. Changing something for one morning happens
/// on the main screen and leaves this alone.
struct DefaultsView: View {
  @Bindable var defaults: BrewDefaults

  var body: some View {
    Form {
      Section("Filter Paper") {
        ForEach(Filter.all) { paper in
          ChoiceRow(label: paper.name, isChosen: paper == defaults.filter) {
            defaults.filter = paper
          }
        }
      }

      Section {
        ForEach(Grinder.all) { grinder in
          ChoiceRow(label: grinder.name, isChosen: grinder == defaults.grinder) {
            defaults.grinder = grinder
          }
        }
      } header: {
        Text("Grinder")
      } footer: {
        Text("The size below reads on whichever grinder you pick.")
      }

      Section {
        // One detent at a time on the chosen grinder. Stepping by a round
        // number of microns would be arbitrary: a click near the middle of a
        // dial moves the grind several times further than one near an end.
        Stepper {
          LabelledValue(
            label: "\(defaults.grinder.setting(forMicron: defaults.microns).formatted) on the dial",
            value: Format.microns(defaults.microns)
          )
        } onIncrement: {
          defaults.microns = defaults.grinder.stepped(defaults.microns, by: 1)
        } onDecrement: {
          defaults.microns = defaults.grinder.stepped(defaults.microns, by: -1)
        }
      } header: {
        Text("Grind")
      } footer: {
        Text(otherGrinders)
      }

      Section("Temperature") {
        Stepper(value: $defaults.brewTemperature, in: 60 ... 100, step: 1) {
          LabelledValue(label: "Kettle", value: Format.degrees(defaults.brewTemperature))
        }
        Stepper(value: $defaults.temperatureTarget, in: 40 ... 100, step: 1) {
          LabelledValue(label: "Last pour", value: Format.degrees(defaults.temperatureTarget))
        }
      }

      Section {
        // Two numbers, because only one of the three scales. A single total
        // would have to assume a number of people, and this screen sets what
        // every brew starts from rather than one of them.
        LabelledValue(label: "Total", value: preheatTotal)
          .fontWeight(.semibold)
        Stepper(value: $defaults.preheat.cone, in: 0 ... 400, step: PreheatPlan.step) {
          LabelledValue(label: "Cone", value: defaults.preheat.cone.millilitres)
        }
        Stepper(value: $defaults.preheat.vessel, in: 0 ... 300, step: PreheatPlan.step) {
          LabelledValue(label: "Vessel", value: defaults.preheat.vessel.millilitres)
        }
        Stepper(value: $defaults.preheat.perCup, in: 0 ... 200, step: PreheatPlan.step) {
          LabelledValue(label: "Cup", value: defaults.preheat.perCup.millilitres)
        }
        Stepper(value: $defaults.preheat.safety, in: 0 ... 100, step: PreheatPlan.step) {
          LabelledValue(label: "Slack", value: defaults.preheat.safety.millilitres)
        }
      } header: {
        Text("Preheat")
      } footer: {
        Text("Cup is per person. The rest are the same however many are drinking.")
      }
    }
    .navigationTitle("Defaults")
    .navigationBarTitleDisplayMode(.inline)
  }

  /// The part that never changes, and the part that does.
  private var preheatTotal: String {
    let each = Format.number(defaults.preheat.perCup)
    return "\(defaults.preheat.fixed.millilitres) + \(each) each"
  }

  /// What the same size reads on the grinders you did not pick.
  private var otherGrinders: String {
    Grinder.all
      .filter { $0 != defaults.grinder }
      .map { grinder in
        let dial = grinder.canReach(defaults.microns)
          ? grinder.setting(forMicron: defaults.microns).formatted
          : "out of range"
        return "\(grinder.name): \(dial)"
      }
      .joined(separator: "\n")
  }
}

/// One thing you can pick, with a tick against the one in force.
private struct ChoiceRow: View {
  let label: String
  let isChosen: Bool
  let choose: () -> Void

  var body: some View {
    Button(action: choose) {
      HStack {
        Text(label)
          .foregroundStyle(.primary)
        Spacer()
        if isChosen {
          Image(systemName: "checkmark")
            .foregroundStyle(.tint)
            .fontWeight(.semibold)
        }
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
