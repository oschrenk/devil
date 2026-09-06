/// What gets warmed before the coffee, and with how much.
///
/// Three separate amounts rather than one total, because only one of them
/// scales. The cup is per person; the vessel and the cone are the same however
/// many people are drinking.
public struct PreheatPlan: Equatable, Sendable {
  /// Per cup, so this is the part that grows with the people.
  public var perCup: Double
  /// The server the brew lands in.
  public var vessel: Double
  /// The Switch and its filter. This pour rinses the paper as well as warming
  /// the cone, which is why it is the largest of the three.
  public var cone: Double
  /// Slack on the kettle fill. You cannot pour off an exact amount, so the
  /// kettle is filled a little over and the remainder stays behind.
  public var safety: Double

  public init(perCup: Double = 50, vessel: Double = 50, cone: Double = 150, safety: Double = 25) {
    self.perCup = perCup
    self.vessel = vessel
    self.cone = cone
    self.safety = safety
  }

  /// The cone and the vessel, which are the same however many are drinking.
  ///
  /// The slack is not in here. It warms nothing, and adding it would make the
  /// preheat total disagree with the one the brew screen reports.
  public var fixed: Double {
    cone + vessel
  }

  /// Five millilitres a press.
  ///
  /// Ten was too coarse to settle on a kettle fill: the boil figure is the sum
  /// of four of these, so a ten-step in any of them moved the total by ten.
  public static let step = 5.0

  public static let standard = PreheatPlan()
}

/// A preheat worked out for a given number of people.
public struct Preheat: Equatable, Sendable {
  public var temperature: Double
  /// All the cups together, not one of them.
  public var cups: Double
  public var vessel: Double
  public var cone: Double
  public var safety: Double

  public init(
    temperature: Double,
    cups: Double,
    vessel: Double,
    cone: Double,
    safety: Double
  ) {
    self.temperature = temperature
    self.cups = cups
    self.vessel = vessel
    self.cone = cone
    self.safety = safety
  }

  public var total: Double {
    cups + vessel + cone
  }

  /// The cone and the vessel are warmed in one pass, poured through the Switch
  /// with the filter in place and into the server below.
  public var throughBrewer: Double {
    cone + vessel
  }
}
