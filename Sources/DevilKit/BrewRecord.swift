/// One brew, as it goes to disk.
///
/// The numbers are stored rather than derived from `BrewSettings` at read
/// time. A record is a fact about a morning that has already happened, and
/// re-deriving it would let a change to `Scaling` rewrite last week's brews.
public struct BrewRecord: Equatable, Sendable {
  public var stamp: BrewStamp
  public var recipe: String
  public var servings: Int
  public var dose: Double
  public var water: Double
  public var grind: Double
  public var grinder: String
  public var filter: String
  public var brewTemperature: Double
  public var temperatureTarget: Double
  public var beakerA: Double
  public var beakerB: Double
  /// Whether the brew reached its last step, rather than ending early.
  public var finished: Bool
  /// The name of the sidecar holding the pour, or `nil` with no scale.
  public var trace: String?
  public var notes: BrewNotes

  public init(
    stamp: BrewStamp,
    recipe: String = "Hario Switch, Water and Temp Managed",
    servings: Int,
    dose: Double,
    water: Double,
    grind: Double,
    grinder: String = "1Zpresso K-Ultra",
    filter: String,
    brewTemperature: Double,
    temperatureTarget: Double,
    beakerA: Double,
    beakerB: Double,
    finished: Bool,
    trace: String? = nil,
    notes: BrewNotes = BrewNotes()
  ) {
    self.stamp = stamp
    self.recipe = recipe
    self.servings = servings
    self.dose = dose
    self.water = water
    self.grind = grind
    self.grinder = grinder
    self.filter = filter
    self.brewTemperature = brewTemperature
    self.temperatureTarget = temperatureTarget
    self.beakerA = beakerA
    self.beakerB = beakerB
    self.finished = finished
    self.trace = trace
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
      grind: settings.grindSetting,
      filter: settings.filter.name,
      brewTemperature: settings.brewTemperature,
      temperatureTarget: settings.temperatureTarget,
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
