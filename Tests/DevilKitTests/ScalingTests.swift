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
    let recipe = Recipe.switchWaterAndTempManaged(
      for: .documented(servings: row.servings)
    )

    #expect(recipe.dose == row.dose)
    #expect(recipe.waterThroughBed == row.water)
    #expect(recipe.kettleFill.tap == row.tap)
    #expect(recipe.finish == row.finish)

    // The beakers agree at one serving and part company after it, on purpose.
    // The sheet types 85.5 into every row, so its cold water is sized as if a
    // five-cup kettle cooled as fast as a one-cup kettle. `temperatureDrop`
    // says it does not, and the deviation below is that disagreement.
    if row.servings == 1 {
      #expect(recipe.kettleFill.demineralized == row.beakerA)
      #expect(recipe.cooler.amount == row.beakerB)
    } else {
      #expect(recipe.cooler.amount > row.beakerB)
      #expect(recipe.kettleFill.demineralized < row.beakerA)
    }
  }

  /// What the sheet would have said if it had let the kettle cool by size.
  ///
  /// Kept as a number rather than a direction, so a change to the cooling
  /// model has to be looked at rather than absorbed.
  @Test("The cold water grows where the sheet held it flat")
  func deviationFromTheSheet() {
    let cooling = (1 ... 5).map {
      Recipe.switchWaterAndTempManaged(for: .documented(servings: $0)).cooler.amount
    }

    #expect(cooling == [12, 20.5, 29, 37.5, 46])
    // The sheet: 12, 18.5, 24, 30.5, 36.
    #expect(cooling[4] - 36 == 10)
  }

  /// The property the whole recipe turns on, at every size.
  @Test("The kettle empties and the cup stays 50:50 at every size", arguments: sheet)
  func kettleEmptiesAndBlendHolds(row: Row) {
    let recipe = Recipe.switchWaterAndTempManaged(
      for: .documented(servings: row.servings)
    )

    #expect(abs(recipe.leftInKettle.total) < 0.000_001)
    #expect(abs(recipe.delivered.tapFraction - 0.5) < 0.000_001)
    #expect(abs(recipe.delivered.tap - row.water / 2) < 0.000_001)
    #expect(abs(recipe.delivered.total - row.water) < 0.000_001)
  }

  @Test("The last pour lands on target at every size", arguments: sheet)
  func temperatureHolds(row: Row) {
    let recipe = Recipe.switchWaterAndTempManaged(
      for: .documented(servings: row.servings)
    )

    #expect(abs(recipe.kettleTemperatureAfterCooler - 75) < 0.5)
  }

  @Test("The ratio stays at 1 : 16.7 at every size", arguments: sheet)
  func ratioHolds(row: Row) {
    let recipe = Recipe.switchWaterAndTempManaged(
      for: .documented(servings: row.servings)
    )

    #expect(abs(recipe.brewRatio - 16.667) < 0.001)
  }

  @Test("Two servings is 22.5 g and 375 g, not a doubling")
  func twoServings() {
    let two = Recipe.switchWaterAndTempManaged(
      for: .documented(servings: 2)
    )

    #expect(two.dose == 22.5)
    #expect(two.waterThroughBed == 375)
    #expect(two.dose != 30)
  }

  @Test("One serving is what RECIPE.md describes")
  func oneServingIsTheDefault() {
    #expect(Recipe.switchWaterAndTempManaged(for: .documented)
      == Recipe.switchWaterAndTempManaged(for: .documented(servings: 1)))
  }

  /// Above the sizes the spreadsheet timed there is no finish to report, and
  /// the schedule stops at the drain rather than inventing one.
  @Test("Past the timed sizes the finish is unknown, not guessed")
  func finishIsUnknownPastTheTable() {
    let five = Recipe.switchWaterAndTempManaged(
      for: .documented(servings: 5)
    )

    #expect(five.finish == nil)
    #expect(five.steps.last?.title == "Drain")
    #expect(Scaling.finish(servings: 9) == nil)
  }

  @Test("The pour times hold at every size, and only the drawdown moves")
  func pourTimesAreFixed() {
    let starts = sheet.map { row in
      Recipe.switchWaterAndTempManaged(for: .documented(servings: row.servings))
        .steps.prefix(6).map(\.start)
    }

    #expect(starts.allSatisfy { $0 == starts[0] })
  }
}

@Suite("Temperature as a control")
struct TemperatureSettingTests {
  /// The drop is no longer a fixed 6.5, so 88 does not land on 81.5. A kettle
  /// set closer to the room has less to lose, and falls about 6.1 instead.
  @Test("A cooler brew still lands the last pour on target")
  func coolerBrew() {
    let recipe = Recipe.switchWaterAndTempManaged(
      for: BrewSettings(brewTemperature: 88)
    )

    #expect(recipe.brewTemperature == 88)
    #expect(recipe.kettleTemperatureAtLastPour > 81.5)
    #expect(recipe.kettleTemperatureAtLastPour < 88)
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

@Suite("Preheat")
struct PreheatTests {
  /// Only the cup scales. The vessel and the cone are the same however many
  /// people are drinking, so the preheat grows by one cup at a time.
  @Test("Only the cup part grows with the people")
  func onlyTheCupScales() {
    for servings in 1 ... 5 {
      let recipe = Recipe.switchWaterAndTempManaged(
        for: .documented(servings: servings)
      )

      #expect(recipe.preheat.cups == 50 * Double(servings))
      #expect(recipe.preheat.vessel == 50)
      #expect(recipe.preheat.cone == 150)
      #expect(recipe.preheat.total == 200 + 50 * Double(servings))
    }
  }

  @Test("The kettle fill is the preheat, the brew tap and the slack")
  func kettleFillScales() {
    let expected: [Int: Double] = [1: 400, 2: 512.5, 3: 625, 4: 737.5, 5: 850]

    for (servings, litres) in expected {
      let recipe = Recipe.switchWaterAndTempManaged(
        for: .documented(servings: servings)
      )
      #expect(recipe.tapToBoil == litres)
    }
  }

  @Test("Skipping a warm-up takes it out of the fill, and nothing else moves")
  func skippingAWarmUp() {
    let full = Recipe.switchWaterAndTempManaged(for: BrewSettings())
    let noCup = Recipe.switchWaterAndTempManaged(
      for: BrewSettings(preheat: PreheatPlan(perCup: 0))
    )

    #expect(noCup.preheat.total == full.preheat.total - 50)
    #expect(noCup.tapToBoil == full.tapToBoil - 50)
    #expect(noCup.delivered == full.delivered)
    #expect(noCup.steps == full.steps)
  }
}
