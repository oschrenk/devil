/// What goes into the kettle before the brew starts.
///
/// There is no buffer here. The recipe sizes the fill so the last pour empties
/// the kettle, and that is what makes the tap-to-demineralized split exact:
/// nothing stays behind to carry water off in the wrong ratio. Filling above
/// this leaves a blended remainder and shifts the cup toward tap.
public struct KettleFill: Equatable, Sendable {
  public var tap: Double
  public var demineralized: Double

  public init(tap: Double, demineralized: Double) {
    self.tap = tap
    self.demineralized = demineralized
  }

  public var blend: Blend {
    Blend(tap: tap, demineralized: demineralized)
  }

  public var total: Double {
    blend.total
  }
}

/// The room-temperature demineralized water that cools the kettle mid-brew.
public struct Cooler: Equatable, Sendable {
  public var amount: Double
  public var temperature: Double

  public init(amount: Double, temperature: Double) {
    self.amount = amount
    self.temperature = temperature
  }
}

/// Water poured before the coffee, to warm the brewer, the server and the cup.
public struct Preheat: Equatable, Sendable {
  public var temperature: Double
  public var throughBrewer: Double
  public var intoCup: Double

  public init(temperature: Double, throughBrewer: Double, intoCup: Double) {
    self.temperature = temperature
    self.throughBrewer = throughBrewer
    self.intoCup = intoCup
  }

  public var total: Double {
    throughBrewer + intoCup
  }
}

/// A whole brew, from the grind setting to the last drip.
///
/// Every stored value appears somewhere in `RECIPE.md`. Everything that can be
/// worked out from those values is computed instead of stored, so the two can
/// never disagree.
public struct Recipe: Equatable, Sendable {
  public var name: String
  public var brewer: String
  public var grinder: String
  public var grindSetting: String
  public var roast: String
  public var dose: Double
  public var kettleFill: KettleFill
  /// What the kettle is set to before the first pour.
  public var brewTemperature: Double
  /// What the kettle reads by the time the last pour comes round, measured
  /// rather than modelled. The kettle sits off its base through the brew and
  /// gives up heat, so sizing the cooler against `brewTemperature` overstates
  /// how much cold water the last pour can absorb.
  public var kettleTemperatureAtLastPour: Double
  public var cooler: Cooler
  /// What the last pour reaches once the cooler goes in.
  public var temperatureTarget: Double
  public var preheat: Preheat
  public var steps: [Step]

  public init(
    name: String,
    brewer: String,
    grinder: String,
    grindSetting: String,
    roast: String,
    dose: Double,
    kettleFill: KettleFill,
    brewTemperature: Double,
    kettleTemperatureAtLastPour: Double,
    cooler: Cooler,
    temperatureTarget: Double,
    preheat: Preheat,
    steps: [Step]
  ) {
    self.name = name
    self.brewer = brewer
    self.grinder = grinder
    self.grindSetting = grindSetting
    self.roast = roast
    self.dose = dose
    self.kettleFill = kettleFill
    self.brewTemperature = brewTemperature
    self.kettleTemperatureAtLastPour = kettleTemperatureAtLastPour
    self.cooler = cooler
    self.temperatureTarget = temperatureTarget
    self.preheat = preheat
    self.steps = steps
  }
}
