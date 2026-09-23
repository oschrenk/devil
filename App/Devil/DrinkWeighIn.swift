import DevilKit
import SwiftUI

/// Weighing what came out, after the brew.
///
/// The tare goes against an empty scale rather than the vessel, because by the
/// time a brew ends the vessel holds the coffee. So the drink is a difference:
/// the total on the scale, less an empty weight the app already knows. That is
/// what the vessel picker is for, and why it matters that it is right.
struct DrinkWeighIn: View {
  let scale: ScaleConnection?
  let recorded: Double?
  let onSave: (Vessel, Double) -> Void

  @State private var vessel: Vessel
  @State private var typed = ""

  init(
    scale: ScaleConnection?,
    vessel: Vessel,
    recorded: Double?,
    onSave: @escaping (Vessel, Double) -> Void
  ) {
    self.scale = scale
    self.recorded = recorded
    self.onSave = onSave
    _vessel = State(initialValue: vessel)
  }

  /// The live reading when there is one, and what you typed when there is not.
  /// A decimal comma is taken as a point, because that is how the weights were
  /// written down.
  private var total: Double? {
    if let weight = scale?.weight, scale?.state.isConnected == true {
      return weight
    }
    return Double(typed.replacingOccurrences(of: ",", with: "."))
  }

  private var drink: Double? {
    total.flatMap(vessel.drink(total:))
  }

  private var isLive: Bool {
    scale?.state.isConnected == true
  }

  var body: some View {
    Section {
      Picker("Vessel", selection: $vessel) {
        ForEach(Vessel.all) { choice in
          Text(choice.name).tag(choice)
        }
      }

      LabelledValue(label: "Empty", value: Format.grams(vessel.weight))

      if isLive {
        LabelledValue(label: "On the scale", value: Format.grams(total ?? 0))
        Button("Tare") { scale?.send(.tare) }
      } else {
        HStack {
          Text("Total")
          Spacer()
          TextField("with vessel", text: $typed)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
      }

      LabelledValue(label: "Drink", value: drink.map(Format.grams) ?? "—")

      Button("Record") {
        if let drink {
          onSave(vessel, drink)
        }
      }
      .disabled(drink == nil)
    } header: {
      Text("Drink")
    } footer: {
      Text(explanation)
    }
  }

  private var explanation: String {
    if let recorded {
      return "Recorded \(Format.grams(recorded)). Weigh again to replace it."
    }
    if isLive {
      return "Tare with nothing on the scale, then set the full vessel down."
    }
    return "No scale. Weigh the full vessel and type the total."
  }
}
