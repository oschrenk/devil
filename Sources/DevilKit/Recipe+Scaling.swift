public extension Recipe {
  /// The recipe in `RECIPE.md`, built for these settings.
  ///
  /// Nothing below is a stored number except the step times and the names.
  /// Weights and beaker fills come out of `Scaling`, so changing the servings
  /// count cannot leave a pour behind at its old size.
  static func switchWaterAndTempManaged(for settings: BrewSettings) -> Recipe {
    let water = Scaling.water(servings: settings.servings)
    let hot = settings.brewTemperature - Scaling.temperatureDropDuringBrew
    let target = settings.temperatureTarget

    return Recipe(
      name: "Hario Switch, Water and Temp Managed",
      brewer: "Hario Switch",
      grinder: "1Zpresso K-Ultra",
      filter: settings.filter,
      roast: "Medium",
      dose: Scaling.dose(servings: settings.servings),
      kettleFill: KettleFill(
        tap: Scaling.tap(water: water),
        demineralized: Scaling.beakerA(water: water, hot: hot, target: target)
      ),
      brewTemperature: settings.brewTemperature,
      kettleTemperatureAtLastPour: hot,
      cooler: Cooler(
        amount: Scaling.beakerB(water: water, hot: hot, target: target),
        temperature: Scaling.roomTemperature
      ),
      temperatureTarget: target,
      preheat: Preheat(temperature: 96, throughBrewer: 200, intoCup: 100),
      steps: schedule(for: settings, water: water, hot: hot, target: target)
    )
  }

  /// One serving, at the recipe's own temperatures. What `RECIPE.md` describes.
  static let switchWaterAndTempManaged = switchWaterAndTempManaged(for: .one)

  /// The pour times never move. Only the weights change with the size, and
  /// only the drawdown changes with the bed.
  private static func schedule(
    for settings: BrewSettings,
    water: Double,
    hot: Double,
    target: Double
  ) -> [Step] {
    let pours = Scaling.pours(water: water)

    var steps: [Step] = [
      Step(
        start: BrewTime(minutes: 0, seconds: 0),
        title: "Bloom",
        switchPosition: .closed,
        actions: [.pour(grams: pours[0])]
      ),
      Step(
        start: BrewTime(minutes: 0, seconds: 10),
        title: "Swirl",
        switchPosition: .closed,
        actions: [.swirl]
      ),
      Step(
        start: BrewTime(minutes: 0, seconds: 30),
        title: "Pour 2",
        // Open the switch first, then pour.
        switchPosition: .open,
        actions: [.pour(grams: pours[1])]
      ),
      Step(
        start: BrewTime(minutes: 1, seconds: 0),
        title: "Pour 3",
        switchPosition: .open,
        actions: [.pour(grams: pours[2])]
      ),
      Step(
        start: BrewTime(minutes: 1, seconds: 45),
        title: "Cold add and swirl",
        // Closed again, so the last pour is an immersion.
        switchPosition: .closed,
        actions: [
          .addCooler(grams: Scaling.beakerB(water: water, hot: hot, target: target)),
          .pour(grams: pours[3]),
          .swirl,
        ]
      ),
      Step(
        start: BrewTime(minutes: 2, seconds: 30),
        title: "Drain",
        switchPosition: .open,
        actions: [.drain]
      ),
    ]

    // Past the sizes the spreadsheet timed there is no finish to show, so the
    // schedule stops at the drain rather than inventing one.
    if let finish = Scaling.finish(servings: settings.servings) {
      steps.append(
        Step(start: finish, title: "Done", switchPosition: .open, actions: [.finish])
      )
    }
    return steps
  }
}
