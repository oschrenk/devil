import DevilKit
import SwiftUI

/// Every brew, newest first.
///
/// The list is read from the folder each time it appears rather than held
/// somewhere. The files are the store, so a brew edited elsewhere shows the
/// edit, and one deleted elsewhere disappears.
struct BrewLogView: View {
  let store: BrewLogStore
  var scale: ScaleConnection?
  var defaults: BrewDefaults?

  @State private var brews: [BrewRecord] = []

  var body: some View {
    List {
      ForEach(brews, id: \.stamp.stem) { brew in
        NavigationLink {
          BrewDetailView(store: store, brew: brew, scale: scale, defaults: defaults)
        } label: {
          BrewRow(brew: brew)
        }
        // A swipe rather than a button in the row, because the row itself
        // is now the way into a brew.
        .swipeActions(edge: .leading) {
          ShareLink(items: store.files(for: brew)) {
            Label("Share", systemImage: "square.and.arrow.up")
          }
          .tint(.accentColor)
        }
      }
      .onDelete { offsets in
        for index in offsets {
          store.delete(brews[index])
        }
        brews.remove(atOffsets: offsets)
      }
    }
    .navigationTitle("Brews")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { EditButton() }
    .overlay {
      if brews.isEmpty {
        ContentUnavailableView(
          "No brews yet",
          systemImage: "cup.and.saucer",
          description: Text("A brew is written down when it ends.")
        )
      }
    }
    .task { brews = store.brews() }
  }
}

/// One morning, told apart from the one before it.
private struct BrewRow: View {
  let brew: BrewRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      // Baselines, not centres. `stopped early` set against the middle of a
      // two-line block floated between them; on the baseline it reads as part
      // of the date it qualifies.
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(brew.stamp.readableDay)
          .font(.headline)
        // The day tells two brews apart. The minute almost never does, so it
        // is here to be checked rather than read.
        Text(brew.stamp.readableTime)
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
        Spacer(minLength: 4)
        if !brew.finished {
          // A short brew is a different morning from a whole one, and the
          // list is the only place that difference shows.
          Text("stopped early")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Text(summary)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
    .padding(.vertical, 2)
  }

  /// The dose, the water it went into, and the grind.
  ///
  /// The servings are gone: the dose already says the size, and says it in
  /// the units the brew was measured in.
  ///
  /// Water in millilitres and coffee in grams. They are the same number for
  /// water, and the different unit is what tells the two figures apart at a
  /// glance.
  private var summary: String {
    let parts = [Format.grams(brew.dose), brew.water.millilitres, "grind \(brew.grind)"]
    return parts.joined(separator: " \u{00B7} ")
  }
}
