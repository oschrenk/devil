/// The four numbers every beaker size is worked out from.
///
/// Together rather than as four parameters, because they always travel
/// together and a function taking all four plus its own arguments is one
/// nobody can call from memory.
private struct Mix {
  let water: Double
  /// The kettle at the last pour, which is below what it was set to.
  let hot: Double
  let target: Double
  let room: Double

  var beakerA: Double {
    Scaling.beakerA(water: water, hot: hot, target: target, room: room)
  }

  var beakerB: Double {
    Scaling.beakerB(water: water, hot: hot, target: target, room: room)
  }
}

public extension Recipe {
  /// The recipe in `RECIPE.md`, built for these settings.
  ///
  /// Nothing below is a stored number except the step times and the names.
  /// Weights and beaker fills come out of `Scaling`, so changing the servings
  /// count cannot leave a pour behind at its old size.
  static func switchWaterAndTempManaged(for settings: BrewSettings) -> Recipe {
    let mix = Mix(
      water: Scaling.water(servings: settings.servings),
      hot: settings.brewTemperature - Scaling.temperatureDrop(
        water: Scaling.water(servings: settings.servings),
        brewTemperature: settings.brewTemperature,
        room: settings.roomTemperature
      ),
      target: settings.temperatureTarget,
      room: settings.roomTemperature
    )

    return Recipe(
      name: "Hario Switch, Water and Temp Managed",
      brewer: "Hario Switch",
      grinder: "1Zpresso K-Ultra",
      filter: settings.filter,
      grindSetting: settings.grindSetting,
      roast: "Medium",
      dose: Scaling.dose(servings: settings.servings),
      kettleFill: KettleFill(
        tap: Scaling.tap(water: mix.water),
        demineralized: mix.beakerA
      ),
      brewTemperature: settings.brewTemperature,
      kettleTemperatureAtLastPour: mix.hot,
      cooler: Cooler(
        amount: mix.beakerB,
        temperature: mix.room
      ),
      temperatureTarget: mix.target,
      preheat: Preheat(
        // 96 C is the most the kettle manages at this altitude before it
        // bubbles, so it is a ceiling rather than a choice.
        temperature: 96,
        cups: settings.preheat.perCup * Double(settings.servings),
        vessel: settings.preheat.vessel,
        cone: settings.preheat.cone,
        safety: settings.preheat.safety
      ),
      steps: schedule(for: settings, mix: mix)
    )
  }

  /// One serving, at the recipe's own temperatures. What `RECIPE.md` describes.
  static let switchWaterAndTempManaged = switchWaterAndTempManaged(for: .one)

  /// The pour times never move. Only the weights change with the size, and
  /// only the drawdown changes with the bed.
  private static func schedule(for settings: BrewSettings, mix: Mix) -> [Step] {
    let pours = Scaling.pours(water: mix.water)
    let rate = Scaling.pourRate(servings: settings.servings)

    var steps = pouring(pours: pours, rate: rate, mix: mix)

    // Past the sizes the spreadsheet timed there is no finish to show, so the
    // schedule stops at the drain rather than inventing one.
    if let finish = Scaling.finish(servings: settings.servings) {
      steps.append(
        Step(start: finish, title: "Done", switchPosition: .open, actions: [.finish])
      )
    }
    return steps
  }

  /// The steps up to the drain, which are the same clock at every size.
  private static func pouring(pours: [Double], rate: Double, mix: Mix) -> [Step] {
    [
      Step(
        start: BrewTime(minutes: 0, seconds: 0),
        title: "Bloom",
        switchPosition: .closed,
        actions: [.pour(grams: pours[0])],
        pourSeconds: Scaling.bloomSeconds
      ),
      Step(
        start: BrewTime(minutes: 0, seconds: 15),
        title: "Swirl",
        switchPosition: .closed,
        actions: [.swirl]
      ),
      Step(
        start: BrewTime(minutes: 0, seconds: 30),
        title: "Pour 2",
        // Open the switch first, then pour.
        switchPosition: .open,
        actions: [.pour(grams: pours[1])],
        pourSeconds: pours[1] / rate
      ),
      Step(
        start: BrewTime(minutes: 1, seconds: 0),
        title: "Pour 3",
        switchPosition: .open,
        actions: [.pour(grams: pours[2])],
        pourSeconds: pours[2] / rate
      ),
      Step(
        start: BrewTime(minutes: 1, seconds: 45),
        title: "Cold add and swirl",
        // Closed again, so the last pour is an immersion.
        switchPosition: .closed,
        actions: [
          .addCooler(grams: mix.beakerB),
          .pour(grams: pours[3]),
          .swirl,
        ],
        pourSeconds: pours[3] / rate
      ),
      Step(
        start: BrewTime(minutes: 2, seconds: 30),
        title: "Drain",
        switchPosition: .open,
        actions: [.drain]
      ),
    ]
  }
}
