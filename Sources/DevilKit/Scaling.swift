/// The arithmetic behind the recipe, worked out from a servings count.
///
/// Every rule here reproduces a column of the spreadsheet the recipe came
/// from, checked against all five of its rows. Where the sheet rounds, this
/// does not have to: writing the water as 125 x (servings + 1) lands on the
/// same integers its ROUNDUP column does, exactly.
public enum Scaling {
  /// Room temperature, the same figure the spreadsheet uses in every row.
  ///
  /// The default rather than the truth. Cold tap in winter is nearer twelve
  /// and a summer kitchen nearer twenty-four, and the cold share of the last
  /// pour is sized against this number, so `BrewSettings` carries the one in
  /// force and this is where it starts.
  public static let roomTemperature = 20.0

  /// How far the kettle falls between the first pour and the cold add, at one
  /// serving, from 92 °C into a 20 °C room.
  ///
  /// The one measurement everything below is anchored to: 92 set, 85.5 when
  /// the cold water goes in. The spreadsheet types 85.5 into every row, at
  /// every batch size, which cannot be right for the reason `temperatureDrop`
  /// explains.
  public static let referenceDrop = 6.5

  /// The kettle body, as the grams of water that would hold the same heat.
  ///
  /// The spreadsheet weighs the Fellow at 757 g empty. Stainless holds about
  /// an eighth of what water does gram for gram, so the body damps the brew
  /// like another 90 g in the kettle.
  ///
  /// It matters because it is not small. At one serving the kettle holds
  /// about 150 g of water on average, so the body is a third of what has to
  /// cool, and leaving it out would exaggerate how much a bigger batch helps.
  public static let kettleThermalMass = 90.0

  /// What the kettle holds on average between the first pour and the cold
  /// add, as a share of the brew water.
  ///
  /// It starts full and is nearly empty by the cold add. The share is the
  /// same at every size, because the tap, the floor and the pours are all
  /// fractions of the water, so one number covers all five.
  public static let kettleShareOfWater = 0.602

  /// How far the kettle falls before the cold water goes in.
  ///
  /// Newton's law, near enough. A body loses heat in proportion to how far
  /// above the room it is, and warms slowly in proportion to how much there
  /// is of it. Over a drop this small the curve is close to a straight line,
  /// so the drop scales with the gap to the room and against the mass.
  ///
  /// Two things follow that a fixed 6.5 got wrong. A kettle set lower falls
  /// less, because it is closer to the room to begin with. And a bigger batch
  /// falls less, because there is more of it to cool: five servings hold
  /// three times the water of one.
  ///
  /// One measurement stretched by physics, which is not the same as five
  /// measurements. Brewing two and four with a thermometer would replace this
  /// with something better, and `DEVIL-38` is where that goes.
  public static func temperatureDrop(
    water: Double,
    brewTemperature: Double,
    room: Double = roomTemperature
  ) -> Double {
    let mass = kettleShareOfWater * water + kettleThermalMass
    let reference = kettleShareOfWater * Scaling.water(servings: 1) + kettleThermalMass
    let gap = (brewTemperature - room) / (92 - roomTemperature)
    return referenceDrop * gap * (reference / mass)
  }

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
  public static func beakerA(
    water: Double,
    hot: Double,
    target: Double,
    room: Double = roomTemperature
  ) -> Double {
    demineralizedFloor(water: water)
      + hotShareOfLastPour(water: water, hot: hot, target: target, room: room)
  }

  /// Beaker B: the rest of the demineralized water, added cold at the last
  /// pour. Its size is what brings that pour to the target.
  public static func beakerB(
    water: Double,
    hot: Double,
    target: Double,
    room: Double = roomTemperature
  ) -> Double {
    lastPour(water: water) - hotShareOfLastPour(water: water, hot: hot, target: target, room: room)
  }

  /// How long the bloom pour takes.
  ///
  /// Fixed, not derived from a rate. The schedule is the same clock at every
  /// size, so the swirl lands at 0:15 whether the bloom is 50 grams or 112,
  /// and the water has to be in by then. A constant rate would push the pour
  /// past its own swirl at four servings.
  ///
  /// It follows that the rate rises with the size, which is what pouring a
  /// bigger bloom into a bigger bed actually looks like.
  public static let bloomSeconds = 15.0

  /// Grams a second, taken from the bloom and used for the pours after it.
  ///
  /// One measured pour, applied to the rest. The later pours have no marker
  /// to time them against, so this is the honest guess until one exists.
  public static func pourRate(servings: Int) -> Double {
    pours(water: water(servings: servings))[0] / bloomSeconds
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
  static func hotShareOfLastPour(
    water: Double,
    hot: Double,
    target: Double,
    room: Double = roomTemperature
  ) -> Double {
    guard hot > room, target > room else { return lastPour(water: water) }
    let share = lastPour(water: water) * (target - room) / (hot - room)
    // Rounded to the gram, as the spreadsheet does. Beaker B takes the
    // remainder, so the two still sum to the pour and the kettle still empties.
    return share.rounded()
  }
}
