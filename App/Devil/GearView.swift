import DevilKit
import SwiftUI

/// What you brew with, set once rather than every morning.
struct GearView: View {
  @Bindable var gear: Gear

  var body: some View {
    Form {
      Section("Filter Paper") {
        ForEach(Filter.all) { paper in
          ChoiceRow(label: paper.name, isChosen: paper == gear.filter) {
            gear.filter = paper
          }
        }
      }

      Section {
        ForEach(Grinder.all) { grinder in
          ChoiceRow(label: grinder.name, isChosen: grinder == gear.grinder) {
            gear.grinder = grinder
          }
        }
      } header: {
        Text("Grinder")
      } footer: {
        Text("The dial below reads on whichever grinder you pick.")
      }

      Section {
        // One detent at a time on the chosen grinder. Stepping by a round
        // number of microns would be arbitrary: a click near the middle of a
        // dial moves the grind several times further than one near an end.
        Stepper {
          LabelledValue(
            label: "\(gear.grinder.setting(forMicron: gear.microns).formatted) on the dial",
            value: Format.microns(gear.microns)
          )
        } onIncrement: {
          gear.microns = gear.grinder.stepped(gear.microns, by: 1)
        } onDecrement: {
          gear.microns = gear.grinder.stepped(gear.microns, by: -1)
        }
      } header: {
        Text("Grind")
      } footer: {
        Text("Set the size. Each grinder shows the setting of its own that comes closest.")
      }

      Section("On Each Grinder") {
        ForEach(Grinder.all) { grinder in
          LabelledValue(
            label: grinder.name,
            value: grinder.canReach(gear.microns)
              ? grinder.setting(forMicron: gear.microns).formatted
              : "out of range"
          )
        }
      }
    }
    .navigationTitle("Gear")
    .navigationBarTitleDisplayMode(.inline)
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
