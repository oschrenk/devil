public extension Recipe {
  /// The recipe in `RECIPE.md`, at one serving.
  ///
  /// Every number below cites the line it comes from, so the two can be checked
  /// against each other one at a time.
  static let switchWaterAndTempManaged = Recipe(
    name: "Hario Switch, Water and Temp Managed",
    brewer: "Hario Switch",
    grinder: "1Zpresso K-Ultra",
    // The Settings block. Prep step 1 said 8.0 until DEVIL-02 made them agree.
    grindSetting: "7.8",
    roast: "Medium",
    dose: 15,
    kettleFill: KettleFill(
      // 125 g intended brew portion, plus 25 g for kettle dead volume and
      // evaporation, plus Beaker A.
      tap: 125,
      tapBuffer: 25,
      demineralized: 113
    ),
    brewTemperature: 92,
    // Beaker B, held at room temperature.
    cooler: Cooler(amount: 13, temperature: 20),
    // Measured at the bed, not worked out from the kettle. Adding 13 g at 20 C
    // to the kettle leaves the water near 83 C; the bed reads lower because it
    // has been cooling since the 1:00 pour.
    bedTemperatureTarget: 75,
    preheat: Preheat(temperature: 96, throughBrewer: 200, intoCup: 100),
    steps: [
      Step(
        start: BrewTime(minutes: 0, seconds: 0),
        title: "Bloom",
        switchPosition: .closed,
        actions: [.pour(grams: 50)]
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
        actions: [.pour(grams: 50)]
      ),
      Step(
        start: BrewTime(minutes: 1, seconds: 0),
        title: "Pour 3",
        switchPosition: .open,
        actions: [.pour(grams: 75)]
      ),
      Step(
        start: BrewTime(minutes: 1, seconds: 45),
        title: "Cold add and swirl",
        // Closed again, so the last pour is an immersion.
        switchPosition: .closed,
        actions: [.addCooler(grams: 13), .pour(grams: 75), .swirl]
      ),
      Step(
        start: BrewTime(minutes: 2, seconds: 30),
        title: "Drain",
        switchPosition: .open,
        actions: [.drain]
      ),
      Step(
        start: BrewTime(minutes: 3, seconds: 30),
        title: "Done",
        switchPosition: .open,
        actions: [.finish]
      ),
    ]
  )
}
