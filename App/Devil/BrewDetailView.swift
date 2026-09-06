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

  @Environment(\.scenePhase) private var scenePhase
  @State private var notes: String
  @State private var pour: PourTrace?

  init(store: BrewLogStore, brew: BrewRecord) {
    self.store = store
    self.brew = brew
    _notes = State(initialValue: brew.notes)
  }

  var body: some View {
    Form {
      Section("Brewed") {
        LabelledValue(label: "When", value: brew.stamp.readable)
        LabelledValue(label: "Cups", value: "\(brew.servings)")
        LabelledValue(label: "Dose", value: Format.grams(brew.dose))
        LabelledValue(label: "Water", value: Format.grams(brew.water))
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
            total: Double(Recipe.switchWaterAndTempManaged.totalTime.seconds),
            ceiling: brew.water
          )
          .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
      }

      Section("Notes") {
        TextField("Beans, water, how it tasted", text: $notes, axis: .vertical)
          .lineLimit(4 ... 20)
      }
    }
    .navigationTitle(brew.stamp.readable)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ShareLink(items: store.files(for: brew)) {
        Label("Share", systemImage: "square.and.arrow.up")
      }
    }
    .task { pour = store.pour(for: brew) }
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
