/// What changes from one morning to the next.
///
/// Everything else about the brew follows from these four. The recipe is not
/// stored anywhere as a table of numbers; it is generated from this, so a
/// setting cannot drift out of step with the pour it implies.
public struct BrewSettings: Equatable, Sendable {
  /// People, not cups of water. The dose per extra person is smaller than the
  /// first, so this is not a multiplier. See `Scaling.dose(servings:)`.
  public var servings: Int
  /// What the kettle is set to before the first pour.
  public var brewTemperature: Double
  /// What the last pour should reach once the cooler goes in.
  public var temperatureTarget: Double
  /// How warm the water you are not heating is.
  ///
  /// The cold share of the last pour is sized against this, so it decides how
  /// much goes in beaker B. Cold tap in winter is nearer twelve than twenty,
  /// and at four servings that is several grams.
  public var roomTemperature: Double
  /// The paper. Its `defaultGrind` is where `grindSetting` starts.
  public var filter: Filter
  /// Which burrs `grindSetting` counts on.
  public var grinder: Grinder
  /// The grinder setting in force.
  ///
  /// The grind, in microns.
  ///
  /// Recorded rather than used: nothing in the recipe is computed from it.
  /// Held as a size rather than a dial number, because a dial number belongs
  /// to one grinder and a size is the same coffee on any of them.
  public var grindMicrons: Double
  /// How much water warms the cup, the vessel and the cone.
  public var preheat: PreheatPlan

  public init(
    servings: Int = 1,
    brewTemperature: Double = 92,
    temperatureTarget: Double = 75,
    roomTemperature: Double = Scaling.roomTemperature,
    filter: Filter = .harioV60Natural,
    grinder: Grinder = .oneZpressoKUltra,
    grindMicrons: Double = BrewSettings.defaultMicrons,
    preheat: PreheatPlan = .standard
  ) {
    self.servings = servings
    self.brewTemperature = brewTemperature
    self.temperatureTarget = temperatureTarget
    self.roomTemperature = roomTemperature
    self.filter = filter
    self.grinder = grinder
    self.grindMicrons = grindMicrons
    self.preheat = preheat
  }

  /// Where `7.6` on the K-Ultra lands, which is where Oliver has this recipe
  /// dialled in.
  public static let defaultMicrons = 583.0

  /// Which detent on the chosen grinder comes closest to the size.
  public var grindSetting: GrindSetting {
    grinder.setting(forMicron: grindMicrons)
  }

  /// Whether the chosen grinder can be set to the size at all.
  ///
  /// The K-Ultra stops at 760 microns and the Ode starts at 550, so a size
  /// picked for one can be off the end of the other.
  public var grinderCanReach: Bool {
    grinder.canReach(grindMicrons)
  }

  public static let one = BrewSettings()

  /// The range the recipe has been brewed across. Above this the finish time
  /// is unknown, and `Scaling` says so rather than extrapolating.
  public static let servingsRange = 1 ... 5
}
