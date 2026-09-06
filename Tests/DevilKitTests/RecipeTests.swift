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
    #expect(recipe.grindSetting == "7.8")
    #expect(recipe.roast == "Medium")
    #expect(recipe.dose == 15)
    #expect(recipe.brewTemperature == 92)
    #expect(recipe.bedTemperatureTarget == 75)
  }

  @Test("The preheat is 300 g, split 200 through the brewer and 100 into the cup")
  func preheat() {
    #expect(recipe.preheat.temperature == 96)
    #expect(recipe.preheat.throughBrewer == 200)
    #expect(recipe.preheat.intoCup == 100)
    #expect(recipe.preheat.total == 300)
  }

  @Test("The kettle holds 150 g tap and 113 g demineralized, so 263 g")
  func kettleFill() {
    #expect(recipe.kettleFill.tap == 125)
    #expect(recipe.kettleFill.tapBuffer == 25)
    #expect(recipe.kettleFill.demineralized == 113)
    #expect(recipe.kettleFill.total == 263)
  }

  @Test("Beaker B holds 13 g of demineralized water at room temperature")
  func cooler() {
    #expect(recipe.cooler.amount == 13)
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

  @Test("The kettle keeps 26 g back, which is close to the 25 g buffer")
  func leftInKettle() {
    #expect(abs(recipe.leftInKettle.total - 26) < 0.5)
  }

  /// `RECIPE.md` claimed 126 g demineralized against 124 g tap, and read the
  /// leftover in the kettle as pure tap. The kettle is one blend, so the
  /// leftover is blended too, and the coffee gets 137 g tap against 113 g.
  @Test("The coffee receives 137 g tap and 113 g demineralized, near 55:45")
  func deliveredBlend() {
    let delivered = recipe.delivered

    #expect(abs(delivered.total - 250) < 0.001)
    #expect(abs(delivered.tap - 137.1) < 0.1)
    #expect(abs(delivered.demineralized - 112.9) < 0.1)
    #expect(abs(delivered.tapFraction - 0.548) < 0.001)
  }

  @Test("A 50:50 cup would need 141 g in Beaker A, not 113 g")
  func beakerAForAnEvenBlend() {
    let needed = recipe.beakerA(forTapFraction: 0.5)

    #expect(abs(needed - 141) < 1)

    var even = recipe
    even.kettleFill.demineralized = needed
    #expect(abs(even.delivered.tap - 125) < 0.5)
    #expect(abs(even.delivered.demineralized - 125) < 0.5)
  }

  /// `RECIPE.md` said the cold add drops the kettle to ~75 C. It reaches 82.7 C.
  /// The 75 C figure is the bed, which reads lower than the water.
  @Test("The cold add leaves the kettle at 82.7 C, not the bed target of 75 C")
  func kettleTemperatureAfterCooler() {
    #expect(abs(recipe.kettleTemperatureAfterCooler - 82.7) < 0.1)
    #expect(recipe.kettleTemperatureAfterCooler > recipe.bedTemperatureTarget)
  }

  @Test("Reaching 75 C in the kettle would need 27 g, not 13 g")
  func coolerForSeventyFive() {
    var colder = recipe
    colder.cooler.amount = 27
    colder.steps = colder.steps.map { step in
      guard step.coolerAdded > 0 else { return step }
      var updated = step
      updated.actions = [.addCooler(grams: 27), .pour(grams: 75), .swirl]
      return updated
    }

    #expect(abs(colder.kettleTemperatureAfterCooler - 75) < 0.5)
  }
}
