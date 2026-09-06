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
  /// The paper. Its `defaultGrind` is where `grindSetting` starts.
  public var filter: Filter
  /// The grinder setting in force.
  ///
  /// Recorded rather than used: nothing in the recipe is computed from it. It
  /// is here so a brew can be written down and dialled in, which is why it is
  /// free to move rather than pinned to the filter.
  public var grindSetting: Double
  /// How much water warms the cup, the vessel and the cone.
  public var preheat: PreheatPlan

  public init(
    servings: Int = 1,
    brewTemperature: Double = 92,
    temperatureTarget: Double = 75,
    filter: Filter = .harioV60Size02,
    grindSetting: Double? = nil,
    preheat: PreheatPlan = .standard
  ) {
    self.servings = servings
    self.brewTemperature = brewTemperature
    self.temperatureTarget = temperatureTarget
    self.filter = filter
    self.grindSetting = grindSetting ?? filter.defaultGrind
    self.preheat = preheat
  }

  /// The range the K-Ultra dial covers for this brewer, in clicks of 0.1.
  public static let grindRange = 6.0 ... 10.0

  public static let one = BrewSettings()

  /// The range the recipe has been brewed across. Above this the finish time
  /// is unknown, and `Scaling` says so rather than extrapolating.
  public static let servingsRange = 1 ... 5
}
