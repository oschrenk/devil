import DevilKit
import SwiftUI

/// The gear you reach for, and the size you grind at.
///
/// Kept in `UserDefaults` rather than beside the brews. A brew is a record of
/// a morning and belongs in a file; this is a preference, and a preference
/// that needed a file read to answer would slow the screen you open first.
@Observable
final class Gear {
  private enum Key {
    static let filter = "defaultFilter"
    static let grinder = "defaultGrinder"
    static let microns = "defaultMicrons"
  }

  /// Stored by name, so gear that changes shape later cannot break the
  /// preference, and an unknown name falls back rather than crashing.
  var filter: Filter {
    didSet { store.set(filter.name, forKey: Key.filter) }
  }

  var grinder: Grinder {
    didSet { store.set(grinder.name, forKey: Key.grinder) }
  }

  /// The size a brew starts at, before you nudge it for the bean.
  var microns: Double {
    didSet { store.set(microns, forKey: Key.microns) }
  }

  private let store: UserDefaults

  init(store: UserDefaults = .standard) {
    self.store = store
    let filterName = store.string(forKey: Key.filter)
    let grinderName = store.string(forKey: Key.grinder)
    let saved = store.object(forKey: Key.microns) as? Double
    filter = Filter.all.first { $0.name == filterName } ?? Filter.all[0]
    grinder = Grinder.all.first { $0.name == grinderName } ?? Grinder.all[0]
    microns = saved ?? BrewSettings.defaultMicrons
  }

  /// What a new brew starts from.
  func settings() -> BrewSettings {
    BrewSettings(filter: filter, grinder: grinder, grindMicrons: microns)
  }
}
