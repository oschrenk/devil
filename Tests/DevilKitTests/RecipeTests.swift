@testable import DevilKit
import Testing

/// Every expectation here cites `RECIPE.md`, so the two can be checked against
/// each other one number at a time.
@Suite("Hario Switch, Water and Temp Managed")
struct RecipeTests {
  let recipe = Recipe.switchWaterAndTempManaged

  @Test("The settings block")
  func settings() {
    #expect(recipe.brewer == "Hario Switch")
    #expect(recipe.grinder == "1Zpresso K-Ultra")
    #expect(recipe.filter == .harioV60Natural)
    #expect(recipe.roast == "Medium")
    #expect(recipe.dose == 15)
    #expect(recipe.brewTemperature == 92)
    #expect(recipe.kettleTemperatureAtLastPour == 85.5)
    #expect(recipe.temperatureTarget == 75)
  }

  /// A paper carries no grind of its own for now, so both start at the size
  /// this recipe was dialled in at.
  @Test("An unset grind starts at the size in the settings")
  func grindDefaultsToTheSize() {
    #expect(recipe.grindSetting == GrindSetting(number: 7, click: 6))

    let abaca = Recipe.switchWaterAndTempManaged(for: BrewSettings(filter: .cafecAbaca))
    #expect(abaca.grindSetting == recipe.grindSetting)

    // Swapping paper changes nothing about the water.
    #expect(abaca.delivered == recipe.delivered)
    #expect(abaca.waterThroughBed == recipe.waterThroughBed)
  }

  /// It is recorded, not used, so it has to be free to move.
  @Test("A grind set by hand overrides the filter and changes nothing else")
  func grindIsAdjustable() {
    let dialled = Recipe.switchWaterAndTempManaged(
      for: BrewSettings(filter: .cafecAbaca, grindMicrons: 700)
    )

    #expect(dialled.grindSetting == GrindSetting(number: 8, click: 9))
    #expect(dialled.filter == .cafecAbaca)
    #expect(dialled.delivered == recipe.delivered)
    #expect(dialled.kettleFill == recipe.kettleFill)
    #expect(dialled.cooler == recipe.cooler)
    #expect(dialled.steps == recipe.steps)
  }

  @Test("A grind keeps its decimal, because that digit is a click")
  func grindFormatting() {
    #expect(Format.grind(7.9) == "7.9")
    #expect(Format.grind(8) == "8.0")
    #expect(Format.grind(8.25) == "8.3")
  }

  @Test("The preheat is 250 ml for one: 150 cone, 50 vessel, 50 cup")
  func preheat() {
    #expect(recipe.preheat.temperature == 96)
    #expect(recipe.preheat.cone == 150)
    #expect(recipe.preheat.vessel == 50)
    #expect(recipe.preheat.cups == 50)
    #expect(recipe.preheat.total == 250)
    // The cone and the vessel are warmed in one pass through the Switch.
    #expect(recipe.preheat.throughBrewer == 200)
  }

  /// The number to act on before anything else is on: one kettle fill covering
  /// the preheat, the brew's tap portion and the slack.
  @Test("One kettle fill is 400 ml of tap for one person")
  func tapToBoil() {
    #expect(recipe.tapToBoil == 400)
    #expect(recipe.tapToBoil == recipe.preheat.total + 25 + recipe.kettleFill.tap)
  }

  @Test("The kettle holds 125 g tap and 113 g demineralized, so 238 g")
  func kettleFill() {
    #expect(recipe.kettleFill.tap == 125)
    #expect(recipe.kettleFill.demineralized == 113)
    #expect(recipe.kettleFill.total == 238)
  }

  @Test("Beaker B holds 12 g of demineralized water at room temperature")
  func cooler() {
    #expect(recipe.cooler.amount == 12)
    #expect(recipe.cooler.temperature == 20)
  }

  @Test("The hot pours total 175 g, and 250 g reaches the bed")
  func waterThroughBed() {
    let hot = recipe.steps
      .filter { $0.start < BrewTime(minutes: 1, seconds: 45) }
      .reduce(0) { $0 + $1.poured }

    #expect(hot == 175)
    #expect(recipe.waterThroughBed == 250)
  }

  @Test("The brew ratio is 1 : 16.7")
  func brewRatio() {
    #expect(abs(recipe.brewRatio - 16.7) < 0.05)
  }

  /// The whole recipe turns on this. Empty the kettle and the coffee receives
  /// everything that went in, so the blend is exactly what was measured out.
  /// Leave water behind and it carries demineralized water off with it.
  @Test("The last pour empties the kettle")
  func kettleEmpties() {
    #expect(abs(recipe.leftInKettle.total) < 0.001)
  }

  @Test("The coffee receives 125 g tap and 125 g demineralized, exactly 50:50")
  func deliveredBlend() {
    let delivered = recipe.delivered

    #expect(abs(delivered.total - 250) < 0.001)
    #expect(abs(delivered.tap - 125) < 0.001)
    #expect(abs(delivered.demineralized - 125) < 0.001)
    #expect(abs(delivered.tapFraction - 0.5) < 0.000_001)
  }

  @Test("113 g is the Beaker A fill a 50:50 cup calls for")
  func beakerAMatchesTheEvenBlend() {
    #expect(abs(recipe.beakerA(forTapFraction: 0.5) - 113) < 0.5)
  }

  @Test("The cold add brings the kettle to the 75 C target")
  func kettleTemperatureAfterCooler() {
    #expect(abs(recipe.kettleTemperatureAfterCooler - recipe.temperatureTarget) < 0.05)
  }

  @Test("12 g is the Beaker B fill the 75 C target calls for")
  func coolerMatchesTheTarget() {
    #expect(abs(recipe.cooler(forTemperature: 75) - 12) < 0.5)
    #expect(abs(recipe.kettleBeforeCooler - 63) < 0.001)
  }

  /// The single-fill variant leaves about 150 g of tap in the kettle unless the
  /// surplus is poured off. That 25 g never leaves, and it takes demineralized
  /// water with it, so both the blend and the temperature miss.
  @Test("Skipping the single-fill pour-off costs both the blend and the temperature")
  func singleFillWithoutPouringOff() {
    var sloppy = recipe
    sloppy.kettleFill.tap = 150

    #expect(abs(sloppy.delivered.tapFraction - 0.55) < 0.001)
    #expect(abs(sloppy.leftInKettle.total - 25) < 0.001)
    #expect(abs(sloppy.kettleTemperatureAfterCooler - 77.6) < 0.1)
  }
}
