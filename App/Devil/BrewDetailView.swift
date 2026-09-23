import DevilKit
import SwiftUI

/// One brew, read back.
///
/// What the app measured sits at the top and cannot be edited here. The pour
/// comes next. The fields you type come last, because they are filled in over
/// the days that follow rather than the morning itself.
struct BrewDetailView: View {
  let store: BrewLogStore
  let brew: BrewRecord
  /// `nil` when nothing handed one down. The weigh step then takes a typed
  /// total instead, which is the rule `DEVIL-09` set: the app is whole
  /// without a scale.
  var scale: ScaleConnection?
  var defaults: BrewDefaults?

  @Environment(\.scenePhase) private var scenePhase
  @State private var notes: String
  @State private var pour: PourTrace?
  @State private var heat = HeatTrace()
  @State private var drink: Double?

  init(
    store: BrewLogStore,
    brew: BrewRecord,
    scale: ScaleConnection? = nil,
    defaults: BrewDefaults? = nil
  ) {
    self.store = store
    self.brew = brew
    self.scale = scale
    self.defaults = defaults
    _notes = State(initialValue: brew.notes)
    _drink = State(initialValue: brew.drink)
  }

  /// The one the brew already used, else the one Defaults chose.
  private var vessel: Vessel {
    Vessel.all.first { $0.name == brew.vessel } ?? defaults?.drinkVessel ?? Vessel.all[0]
  }

  /// Rebuilt at the size this brew was, so the intended pour drawn under it
  /// is the one that was intended that morning.
  private var recipe: Recipe {
    .switchWaterAndTempManaged(for: BrewSettings(servings: brew.servings))
  }

  var body: some View {
    Form {
      Section("Brewed") {
        LabelledValue(label: "When", value: brew.stamp.readableDay)
        LabelledValue(label: "Time", value: brew.stamp.readableTime)
        LabelledValue(label: "Cups", value: "\(brew.servings)")
        LabelledValue(label: "Dose", value: Format.grams(brew.dose))
        LabelledValue(label: "Water", value: brew.water.millilitres)
        LabelledValue(label: "Grind", value: brew.grind)
        LabelledValue(label: "Size", value: Format.microns(brew.grindMicrons))
        LabelledValue(label: "Grinder", value: brew.grinder)
        LabelledValue(label: "Filter", value: brew.filter)
        LabelledValue(label: "Temperature", value: Format.degrees(brew.brewTemperature))
        if !brew.finished {
          LabelledValue(label: "Ended", value: "stopped early")
        }
      }

      if let pour, !pour.samples.isEmpty {
        Section("Pour") {
          BrewGraph(
            trace: pour,
            ideal: recipe.idealPour,
            total: Double(recipe.totalTime.seconds),
            ceiling: brew.water,
            heat: heat
          )
          .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
      }

      DrinkWeighIn(scale: scale, vessel: vessel, recorded: drink) { chosen, weight in
        drink = weight
        store.saveDrink(vessel: chosen.name, drink: weight, for: brew)
      }

      Section("Notes") {
        TextField("Beans, water, how it tasted", text: $notes, axis: .vertical)
          .lineLimit(4 ... 20)
      }
    }
    .navigationTitle(brew.stamp.readableDay)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ShareLink(items: store.files(for: brew)) {
        Label("Share", systemImage: "square.and.arrow.up")
      }
    }
    .task {
      pour = store.pour(for: brew)
      heat = store.heat(for: brew)
    }
    // Written when you leave, and again if the app goes to the background
    // with the screen still open, so a note typed and then abandoned is not
    // lost to whatever happens next.
    .onDisappear { store.save(notes, for: brew) }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        store.save(notes, for: brew)
      }
    }
  }
}
