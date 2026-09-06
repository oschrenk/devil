/// What goes into the kettle before the brew starts.
///
/// The tap water is split because the two halves behave differently when the
/// recipe scales. The brew portion is what the ratio is built on. The buffer
/// covers kettle dead volume and evaporation, and stays behind by design.
public struct KettleFill: Equatable, Sendable {
  public var tap: Double
  public var tapBuffer: Double
  public var demineralized: Double

  public init(tap: Double, tapBuffer: Double, demineralized: Double) {
    self.tap = tap
    self.tapBuffer = tapBuffer
    self.demineralized = demineralized
  }

  public var blend: Blend {
    Blend(tap: tap + tapBuffer, demineralized: demineralized)
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
  public var brewTemperature: Double
  public var cooler: Cooler
  /// Observed, not computed. See `kettleTemperatureAfterCooler`.
  public var bedTemperatureTarget: Double
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
    cooler: Cooler,
    bedTemperatureTarget: Double,
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
    self.cooler = cooler
    self.bedTemperatureTarget = bedTemperatureTarget
    self.preheat = preheat
    self.steps = steps
  }
}
