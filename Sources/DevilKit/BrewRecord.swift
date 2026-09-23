/// One brew, as it goes to disk.
///
/// The numbers are stored rather than derived from `BrewSettings` at read
/// time. A record is a fact about a morning that has already happened, and
/// re-deriving it would let a change to `Scaling` rewrite last week's brews.
public struct BrewRecord: Equatable, Sendable, Identifiable {
  /// The stem of both its files, which is unique to the minute it started.
  public var id: String {
    stamp.stem
  }

  public var stamp: BrewStamp
  public var recipe: String
  public var servings: Int
  public var dose: Double
  public var water: Double
  /// The dial as it read, such as `7.9`. Meaningless without `grinder`.
  public var grind: String
  /// The same grind as a size, which means the same on any grinder.
  public var grindMicrons: Double
  public var grinder: String
  public var filter: String
  public var brewTemperature: Double
  public var temperatureTarget: Double
  /// What the unheated water was, which decided how much went in beaker B.
  public var roomTemperature: Double
  public var beakerA: Double
  public var beakerB: Double
  /// Whether the brew reached its last step, rather than ending early.
  public var finished: Bool
  /// The name of the sidecar holding the pour, or `nil` with no scale.
  public var trace: String?
  /// What the drink was poured into, and `nil` for a brew nobody weighed.
  /// Kept beside the weight because the weight is a difference, and a
  /// difference means nothing without the number it came from.
  public var vessel: String?
  /// What came out, in grams, less the vessel.
  public var drink: Double?
  /// Whatever you type afterwards, as prose.
  ///
  /// One field and not a form. A form presumes the vocabulary is settled, and
  /// what is worth tracking about a brew is still an open question.
  public var notes: String

  public init(
    stamp: BrewStamp,
    recipe: String = "Hario Switch, Water and Temp Managed",
    servings: Int,
    dose: Double,
    water: Double,
    grind: String,
    grindMicrons: Double,
    grinder: String = "1Zpresso K-Ultra",
    filter: String,
    brewTemperature: Double,
    temperatureTarget: Double,
    roomTemperature: Double = Scaling.roomTemperature,
    beakerA: Double,
    beakerB: Double,
    finished: Bool,
    trace: String? = nil,
    vessel: String? = nil,
    drink: Double? = nil,
    notes: String = ""
  ) {
    self.stamp = stamp
    self.recipe = recipe
    self.servings = servings
    self.dose = dose
    self.water = water
    self.grind = grind
    self.grindMicrons = grindMicrons
    self.grinder = grinder
    self.filter = filter
    self.brewTemperature = brewTemperature
    self.temperatureTarget = temperatureTarget
    self.roomTemperature = roomTemperature
    self.beakerA = beakerA
    self.beakerB = beakerB
    self.finished = finished
    self.trace = trace
    self.vessel = vessel
    self.drink = drink
    self.notes = notes
  }

  /// Everything a brew needs, worked out from the settings in force.
  public static func of(
    settings: BrewSettings,
    at stamp: BrewStamp,
    finished: Bool,
    trace: String? = nil
  ) -> BrewRecord {
    let water = Scaling.water(servings: settings.servings)
    return BrewRecord(
      stamp: stamp,
      servings: settings.servings,
      dose: Scaling.dose(servings: settings.servings),
      water: water,
      grind: settings.grindSetting.formatted,
      grindMicrons: settings.grindMicrons.rounded(),
      grinder: settings.grinder.name,
      filter: settings.filter.name,
      brewTemperature: settings.brewTemperature,
      temperatureTarget: settings.temperatureTarget,
      roomTemperature: settings.roomTemperature,
      beakerA: Scaling.beakerA(
        water: water,
        hot: settings.brewTemperature,
        target: settings.temperatureTarget
      ),
      beakerB: Scaling.beakerB(
        water: water,
        hot: settings.brewTemperature,
        target: settings.temperatureTarget
      ),
      finished: finished,
      trace: trace
    )
  }
}
