public extension Recipe {
  /// The recipe in `RECIPE.md`, at one serving.
  ///
  /// Every number below cites the line it comes from, so the two can be checked
  /// against each other one at a time.
  static let switchWaterAndTempManaged = Recipe(
    name: "Hario Switch, Water and Temp Managed",
    brewer: "Hario Switch",
    grinder: "1Zpresso K-Ultra",
    // Unresolved. The Settings block says 7.8, Prep step 1 said 8.0, and the
    // spreadsheet the recipe was derived from says 8.1. Nothing decides between
    // them, so the Settings block wins and this stays the one value in the file
    // that rests on no evidence.
    grindSetting: "7.8",
    roast: "Medium",
    dose: 15,
    kettleFill: KettleFill(
      // Half the 250 g is tap, and Beaker A carries the demineralized share
      // that has to be hot. The two total 238 g, which the four pours empty
      // exactly. No buffer: see the note on KettleFill.
      tap: 125,
      demineralized: 113
    ),
    brewTemperature: 92,
    // Measured, not modelled. The kettle is off its base from 0:00 to 1:45.
    kettleTemperatureAtLastPour: 85.5,
    // Beaker B, held at room temperature. 63 g at 85.5 C plus 12 g at 20 C is
    // 75 g at 75 C, which is why the last pour is 75 g and Beaker B is 12 g.
    cooler: Cooler(amount: 12, temperature: 20),
    temperatureTarget: 75,
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
        actions: [.addCooler(grams: 12), .pour(grams: 75), .swirl]
      ),
      Step(
        start: BrewTime(minutes: 2, seconds: 30),
        title: "Drain",
        switchPosition: .open,
        actions: [.drain]
      ),
      Step(
        // Observed, from the spreadsheet's "Finish at" column, which scales
        // with the dose. RECIPE.md read 3:30 off the 30 g row.
        start: BrewTime(minutes: 3, seconds: 15),
        title: "Done",
        switchPosition: .open,
        actions: [.finish]
      ),
    ]
  )
}
