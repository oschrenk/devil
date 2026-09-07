/// Where the Switch valve sits during a step.
///
/// Closed holds the water on the bed and the brew is an immersion. Open lets it
/// drain through and the brew percolates. Every step in the recipe names one,
/// because getting it wrong changes the brew rather than delaying it.
public enum SwitchPosition: String, Equatable, Sendable {
  case closed
  case open
}

/// One thing the brewer does at a step.
public enum Action: Equatable, Sendable {
  /// Pour water from the kettle onto the bed.
  case pour(grams: Double)
  /// Add room-temperature demineralized water to the kettle, not to the bed.
  case addCooler(grams: Double)
  case swirl
  case drain
  case finish
}

/// One entry on the brew clock.
///
/// A step can do several things at once. At 1:45 the recipe closes the switch,
/// tips the cooler into the kettle, pours, and swirls, and splitting that into
/// four steps would imply four waits that do not exist.
public struct Step: Equatable, Sendable {
  public var start: BrewTime
  public var title: String
  public var switchPosition: SwitchPosition
  public var actions: [Action]
  /// How long the pour itself takes.
  ///
  /// The recipe says when a pour starts and never said how long it runs, so
  /// there was no ideal to draw a real pour against. Nothing on screen sets
  /// this: it is the shape the recipe intends, not a number to dial.
  ///
  /// Zero on a step that pours nothing.
  public var pourSeconds: Double

  public init(
    start: BrewTime,
    title: String,
    switchPosition: SwitchPosition,
    actions: [Action],
    pourSeconds: Double = 0
  ) {
    self.start = start
    self.title = title
    self.switchPosition = switchPosition
    self.actions = actions
    self.pourSeconds = pourSeconds
  }

  /// Water poured onto the bed during this step.
  public var poured: Double {
    actions.reduce(0) { total, action in
      if case let .pour(grams) = action {
        return total + grams
      }
      return total
    }
  }

  /// Water added to the kettle during this step, which never touches the bed
  /// directly.
  public var coolerAdded: Double {
    actions.reduce(0) { total, action in
      if case let .addCooler(grams) = action {
        return total + grams
      }
      return total
    }
  }
}
