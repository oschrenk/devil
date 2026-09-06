/// The arithmetic behind the recipe, worked out from a servings count.
///
/// Every rule here reproduces a column of the spreadsheet the recipe came
/// from, checked against all five of its rows. Where the sheet rounds, this
/// does not have to: writing the water as 125 x (servings + 1) lands on the
/// same integers its ROUNDUP column does, exactly.
public enum Scaling {
  /// Room temperature, the same figure the spreadsheet uses in every row.
  public static let roomTemperature = 20.0

  /// How far the kettle falls between the first pour and the last.
  ///
  /// Measured once: 92 °C set, 85.5 °C at the last pour. Held constant when
  /// the brew temperature moves, because one reading cannot show whether the
  /// drop scales with the gap to the room. It is also held constant across
  /// servings, which is what the spreadsheet does, even though a bigger batch
  /// must cool more slowly.
  public static let temperatureDropDuringBrew = 6.5

  /// Coffee, in grams.
  ///
  /// 15 g for one and 22.5 g for two, so the step is 7.5 g and not a doubling.
  /// The first cup carries the losses the rest do not pay again.
  public static func dose(servings: Int) -> Double {
    7.5 * Double(servings + 1)
  }

  /// Water through the bed, in grams. Holds the ratio at 1 : 16.7.
  public static func water(servings: Int) -> Double {
    125 * Double(servings + 1)
  }

  /// The four pours: two fifths of the water in two equal pours, then the rest
  /// split in half.
  public static func pours(water: Double) -> [Double] {
    [water / 5, water / 5, 3 * water / 10, 3 * water / 10]
  }

  /// Tap water for the kettle. Half of everything, because the recipe is a
  /// 50:50 blend and the kettle ends up empty.
  public static func tap(water: Double) -> Double {
    water / 2
  }

  /// Demineralized water the kettle has to hold to cover the first three
  /// pours, once the tap water is in.
  public static func demineralizedFloor(water: Double) -> Double {
    water / 5
  }

  /// Beaker A: the demineralized water that goes in the kettle and is heated.
  ///
  /// The floor above, plus the share of the last pour that has to arrive hot
  /// for the cold water to land it on target.
  public static func beakerA(water: Double, hot: Double, target: Double) -> Double {
    demineralizedFloor(water: water) + hotShareOfLastPour(water: water, hot: hot, target: target)
  }

  /// Beaker B: the rest of the demineralized water, added cold at the last
  /// pour. Its size is what brings that pour to the target.
  public static func beakerB(water: Double, hot: Double, target: Double) -> Double {
    lastPour(water: water) - hotShareOfLastPour(water: water, hot: hot, target: target)
  }

  /// How long the brew takes, observed rather than derived.
  ///
  /// The spreadsheet recorded a finish for the first four sizes and stopped.
  /// Nothing here extrapolates past that: the drawdown grows with the bed, but
  /// by 45, 50, 60 and 70 seconds, which is not a line worth extending.
  public static func finish(servings: Int) -> BrewTime? {
    switch servings {
    case 1: BrewTime(minutes: 3, seconds: 15)
    case 2: BrewTime(minutes: 3, seconds: 20)
    case 3: BrewTime(minutes: 3, seconds: 30)
    case 4: BrewTime(minutes: 3, seconds: 40)
    default: nil
    }
  }

  static func lastPour(water: Double) -> Double {
    3 * water / 10
  }

  /// The hot part of the last pour, sized so that mixing it with the cold
  /// remainder hits the target exactly.
  static func hotShareOfLastPour(water: Double, hot: Double, target: Double) -> Double {
    guard hot > roomTemperature, target > roomTemperature else { return lastPour(water: water) }
    let share = lastPour(water: water) * (target - roomTemperature) / (hot - roomTemperature)
    // Rounded to the gram, as the spreadsheet does. Beaker B takes the
    // remainder, so the two still sum to the pour and the kettle still empties.
    return share.rounded()
  }
}
