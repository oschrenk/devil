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
    #expect(recipe.filter == .harioV60Size02)
    #expect(recipe.roast == "Medium")
    #expect(recipe.dose == 15)
    #expect(recipe.brewTemperature == 92)
    #expect(recipe.kettleTemperatureAtLastPour == 85.5)
    #expect(recipe.temperatureTarget == 75)
  }

  /// The grind is a property of the paper, not of the recipe. Abaca flows
  /// faster than Hario's and needs a finer setting to hold the contact time.
  @Test("The grind follows the filter, 7.9 with Hario and 7.5 with Abaca")
  func grindFollowsTheFilter() {
    #expect(recipe.grindSetting == "7.9")

    var abaca = recipe
    abaca.filter = .abaca
    #expect(abaca.grindSetting == "7.5")

    // Swapping paper changes nothing about the water.
    #expect(abaca.delivered == recipe.delivered)
    #expect(abaca.waterThroughBed == recipe.waterThroughBed)
  }

  @Test("The preheat is 300 g, split 200 through the brewer and 100 into the cup")
  func preheat() {
    #expect(recipe.preheat.temperature == 96)
    #expect(recipe.preheat.throughBrewer == 200)
    #expect(recipe.preheat.intoCup == 100)
    #expect(recipe.preheat.total == 300)
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
