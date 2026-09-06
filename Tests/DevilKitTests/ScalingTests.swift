@testable import DevilKit
import Testing

/// One row of the spreadsheet the recipe came from.
struct Row: Sendable {
  let servings: Int
  let dose: Double
  let water: Double
  let tap: Double
  let beakerA: Double
  let beakerB: Double
  let finish: BrewTime?
}

let sheet = [
  Row(
    servings: 1,
    dose: 15,
    water: 250,
    tap: 125,
    beakerA: 113,
    beakerB: 12,
    finish: BrewTime(minutes: 3, seconds: 15)
  ),
  Row(
    servings: 2,
    dose: 22.5,
    water: 375,
    tap: 187.5,
    beakerA: 169,
    beakerB: 18.5,
    finish: BrewTime(minutes: 3, seconds: 20)
  ),
  Row(
    servings: 3,
    dose: 30,
    water: 500,
    tap: 250,
    beakerA: 226,
    beakerB: 24,
    finish: BrewTime(minutes: 3, seconds: 30)
  ),
  Row(
    servings: 4,
    dose: 37.5,
    water: 625,
    tap: 312.5,
    beakerA: 282,
    beakerB: 30.5,
    finish: BrewTime(minutes: 3, seconds: 40)
  ),
  Row(
    servings: 5,
    dose: 45,
    water: 750,
    tap: 375,
    beakerA: 339,
    beakerB: 36,
    finish: nil
  ),
]

@Suite("Scaling")
struct ScalingTests {
  @Test(
    "Every row of the spreadsheet comes back from the servings count alone",
    arguments: sheet
  )
  func reproducesTheSheet(row: Row) {
    let recipe = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: row.servings))

    #expect(recipe.dose == row.dose)
    #expect(recipe.waterThroughBed == row.water)
    #expect(recipe.kettleFill.tap == row.tap)
    #expect(recipe.kettleFill.demineralized == row.beakerA)
    #expect(recipe.cooler.amount == row.beakerB)
    #expect(recipe.finish == row.finish)
  }

  /// The property the whole recipe turns on, at every size.
  @Test("The kettle empties and the cup stays 50:50 at every size", arguments: sheet)
  func kettleEmptiesAndBlendHolds(row: Row) {
    let recipe = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: row.servings))

    #expect(abs(recipe.leftInKettle.total) < 0.000_001)
    #expect(abs(recipe.delivered.tapFraction - 0.5) < 0.000_001)
    #expect(abs(recipe.delivered.tap - row.water / 2) < 0.000_001)
    #expect(abs(recipe.delivered.total - row.water) < 0.000_001)
  }

  @Test("The last pour lands on target at every size", arguments: sheet)
  func temperatureHolds(row: Row) {
    let recipe = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: row.servings))

    #expect(abs(recipe.kettleTemperatureAfterCooler - 75) < 0.5)
  }

  @Test("The ratio stays at 1 : 16.7 at every size", arguments: sheet)
  func ratioHolds(row: Row) {
    let recipe = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: row.servings))

    #expect(abs(recipe.brewRatio - 16.667) < 0.001)
  }

  @Test("Two servings is 22.5 g and 375 g, not a doubling")
  func twoServings() {
    let two = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: 2))

    #expect(two.dose == 22.5)
    #expect(two.waterThroughBed == 375)
    #expect(two.dose != 30)
  }

  @Test("One serving is what RECIPE.md describes")
  func oneServingIsTheDefault() {
    #expect(Recipe.switchWaterAndTempManaged
      == Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: 1)))
  }

  /// Above the sizes the spreadsheet timed there is no finish to report, and
  /// the schedule stops at the drain rather than inventing one.
  @Test("Past the timed sizes the finish is unknown, not guessed")
  func finishIsUnknownPastTheTable() {
    let five = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: 5))

    #expect(five.finish == nil)
    #expect(five.steps.last?.title == "Drain")
    #expect(Scaling.finish(servings: 9) == nil)
  }

  @Test("The pour times hold at every size, and only the drawdown moves")
  func pourTimesAreFixed() {
    let starts = sheet.map { row in
      Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: row.servings))
        .steps.prefix(6).map(\.start)
    }

    #expect(starts.allSatisfy { $0 == starts[0] })
  }
}

@Suite("Temperature as a control")
struct TemperatureSettingTests {
  @Test("A cooler brew still lands the last pour on target")
  func coolerBrew() {
    let recipe = Recipe.switchWaterAndTempManaged(
      for: BrewSettings(brewTemperature: 88)
    )

    #expect(recipe.brewTemperature == 88)
    #expect(recipe.kettleTemperatureAtLastPour == 81.5)
    #expect(abs(recipe.kettleTemperatureAfterCooler - 75) < 0.5)
  }

  /// Less heat in the kettle means less room for cold water, so Beaker B
  /// shrinks and Beaker A takes what it loses. The two still sum to the pour,
  /// so the blend does not move.
  @Test("Lowering the brew temperature moves water from Beaker B to Beaker A")
  func beakersTradeOff() {
    let warm = Recipe.switchWaterAndTempManaged(for: BrewSettings(brewTemperature: 92))
    let cool = Recipe.switchWaterAndTempManaged(for: BrewSettings(brewTemperature: 88))

    #expect(cool.cooler.amount < warm.cooler.amount)
    #expect(cool.kettleFill.demineralized > warm.kettleFill.demineralized)
    #expect(abs(cool.delivered.tapFraction - 0.5) < 0.01)
    #expect(abs(cool.leftInKettle.total) < 0.000_001)
  }

  @Test("Asking for a hotter last pour needs less cold water")
  func hotterTarget() {
    let cooler = Recipe.switchWaterAndTempManaged(for: BrewSettings(temperatureTarget: 70))
    let hotter = Recipe.switchWaterAndTempManaged(for: BrewSettings(temperatureTarget: 80))

    #expect(hotter.cooler.amount < cooler.cooler.amount)
    #expect(abs(hotter.kettleTemperatureAfterCooler - 80) < 0.5)
    #expect(abs(cooler.kettleTemperatureAfterCooler - 70) < 0.5)
  }
}
