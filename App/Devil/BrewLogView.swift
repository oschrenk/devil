import DevilKit
import SwiftUI

/// Every brew, newest first.
///
/// The list is read from the folder each time it appears rather than held
/// somewhere. The files are the store, so a brew edited elsewhere shows the
/// edit, and one deleted elsewhere disappears.
struct BrewLogView: View {
  let store: BrewLogStore

  @State private var brews: [BrewRecord] = []

  var body: some View {
    List {
      ForEach(brews, id: \.stamp.stem) { brew in
        NavigationLink {
          BrewDetailView(store: store, brew: brew)
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
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(brew.stamp.readable)
          .font(.headline)
          .monospacedDigit()
        Spacer()
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

  private var summary: String {
    let people = brew.servings == 1 ? "1 cup" : "\(brew.servings) cups"
    return "\(people) · \(Format.grams(brew.dose)) · grind \(Format.grind(brew.grind))"
  }
}
