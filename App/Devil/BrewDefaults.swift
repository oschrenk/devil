import DevilKit
import SwiftUI

/// What a brew starts from.
///
/// The settings screen writes these, and the main screen reads them whenever
/// they change. Nothing here is per-brew: changing the temperature for one
/// morning happens on the main screen and leaves these alone.
///
/// Kept in `UserDefaults` rather than beside the brews. A brew is a record of
/// a morning and belongs in a file; this is a preference, and a preference
/// that needed a file read to answer would slow the screen you open first.
@Observable
final class BrewDefaults {
  private enum Key {
    static let filter = "defaultFilter"
    static let grinder = "defaultGrinder"
    static let microns = "defaultMicrons"
    static let brewTemperature = "defaultBrewTemperature"
    static let temperatureTarget = "defaultTemperatureTarget"
    static let roomTemperature = "defaultRoomTemperature"
    static let cone = "defaultConePreheat"
    static let vessel = "defaultVesselPreheat"
    static let perCup = "defaultCupPreheat"
    static let safety = "defaultSlack"
  }

  /// Bumped by every change, so one observer covers the lot. Watching nine
  /// properties one at a time is nine chances to forget the tenth.
  private(set) var revision = 0

  /// Stored by name, so gear that changes shape later cannot break the
  /// preference, and an unknown name falls back rather than crashing.
  var filter: Filter {
    didSet { save(filter.name, Key.filter) }
  }

  var grinder: Grinder {
    didSet { save(grinder.name, Key.grinder) }
  }

  /// The size a brew starts at, before you nudge it for the bean.
  var microns: Double {
    didSet { save(microns, Key.microns) }
  }

  var brewTemperature: Double {
    didSet { save(brewTemperature, Key.brewTemperature) }
  }

  var temperatureTarget: Double {
    didSet { save(temperatureTarget, Key.temperatureTarget) }
  }

  var roomTemperature: Double {
    didSet { save(roomTemperature, Key.roomTemperature) }
  }

  var preheat: PreheatPlan {
    didSet {
      store.set(preheat.cone, forKey: Key.cone)
      store.set(preheat.vessel, forKey: Key.vessel)
      store.set(preheat.perCup, forKey: Key.perCup)
      save(preheat.safety, Key.safety)
    }
  }

  private func save(_ value: Any, _ key: String) {
    store.set(value, forKey: key)
    revision += 1
  }

  private let store: UserDefaults

  init(store: UserDefaults = .standard) {
    self.store = store
    let filterName = store.string(forKey: Key.filter)
    let grinderName = store.string(forKey: Key.grinder)
    let saved = store.number(Key.microns)
    filter = Filter.all.first { $0.name == filterName } ?? Filter.all[0]
    grinder = Grinder.all.first { $0.name == grinderName } ?? Grinder.all[0]
    microns = saved ?? BrewSettings.defaultMicrons
    let standard = BrewSettings.one
    brewTemperature = store.number(Key.brewTemperature) ?? standard.brewTemperature
    temperatureTarget = store.number(Key.temperatureTarget) ?? standard.temperatureTarget
    roomTemperature = store.number(Key.roomTemperature) ?? standard.roomTemperature
    preheat = PreheatPlan(
      perCup: store.number(Key.perCup) ?? PreheatPlan.standard.perCup,
      vessel: store.number(Key.vessel) ?? PreheatPlan.standard.vessel,
      cone: store.number(Key.cone) ?? PreheatPlan.standard.cone,
      safety: store.number(Key.safety) ?? PreheatPlan.standard.safety
    )
  }

  /// What a new brew starts from. Servings is not here: it is the one thing
  /// that changes every morning, so it has no default worth keeping.
  func settings() -> BrewSettings {
    BrewSettings(
      brewTemperature: brewTemperature,
      temperatureTarget: temperatureTarget,
      roomTemperature: roomTemperature,
      filter: filter,
      grinder: grinder,
      grindMicrons: microns,
      preheat: preheat
    )
  }
}

private extension UserDefaults {
  /// `nil` rather than zero when a key was never written, so a default that
  /// happens to be zero is still distinguishable from an absent one.
  func number(_ key: String) -> Double? {
    object(forKey: key) as? Double
  }
}
