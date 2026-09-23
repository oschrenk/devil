@testable import DevilKit
import Testing

@Suite("Ratio")
struct RatioTests {
  /// 50/3 exactly, at every size, because dose and water are both linear in
  /// (servings + 1) and the term cancels.
  @Test("The ratio repeats rather than rounds, at every size")
  func ratioIsExactlyFiftyThirds() {
    for servings in 1 ... 5 {
      let recipe = Recipe.switchWaterAndTempManaged(
        for: .documented(servings: servings)
      )

      #expect(abs(recipe.brewRatio - 50.0 / 3.0) < 0.000_000_1)
      #expect(Format.ratio(recipe.brewRatio) == "1 : 16.6\u{0305}")
    }
  }

  @Test("A ratio that does not repeat is written plainly")
  func otherRatiosFallBack() {
    #expect(Format.ratio(15) == "1 : 15")
    #expect(Format.ratio(16.5) == "1 : 16.5")
  }

  /// The slack warms nothing, so counting it here would put the preheat total
  /// out of step with the one the brew screen reports.
  @Test("The fixed part of a preheat leaves out the cup and the slack")
  func fixedPreheat() {
    #expect(PreheatPlan.standard.fixed == 200)
    #expect(PreheatPlan(perCup: 60, vessel: 40, cone: 120, safety: 30).fixed == 160)
  }

  /// Twenty is where it starts, and the spreadsheet's figure.
  @Test("Room temperature defaults to twenty")
  func defaultRoom() {
    #expect(Scaling.roomTemperature == 20)
    #expect(BrewSettings().roomTemperature == 20)
    #expect(Recipe.switchWaterAndTempManaged.cooler.temperature == 20)
  }

  /// The cold share is sized against the room, so colder water goes further
  /// and less of it is needed.
  @Test("Colder water means less of it")
  func colderRoomNeedsLess() {
    // One thing varied from the documented recipe, so the kettle temperature
    // is the same in all three and only the room differs.
    var warmRoom = BrewSettings.documented
    warmRoom.roomTemperature = 24
    var coldRoom = BrewSettings.documented
    coldRoom.roomTemperature = 12

    let warm = Recipe.switchWaterAndTempManaged(for: warmRoom)
    let standard = Recipe.switchWaterAndTempManaged(for: .documented)
    let cold = Recipe.switchWaterAndTempManaged(for: coldRoom)

    #expect(cold.cooler.amount < standard.cooler.amount)
    #expect(standard.cooler.amount < warm.cooler.amount)
  }

  /// Whatever the room is, the kettle still empties and the bed still takes
  /// the same water. Only the split between the beakers moves.
  @Test("The room moves the split and nothing else")
  func roomOnlyMovesTheSplit() {
    for room in [8.0, 14, 20, 26, 32] {
      let recipe = Recipe.switchWaterAndTempManaged(for: BrewSettings(roomTemperature: room))
      let standard = Recipe.switchWaterAndTempManaged(for: .documented)

      #expect(recipe.waterThroughBed == standard.waterThroughBed)
      #expect(recipe.kettleFill.tap == standard.kettleFill.tap)
      #expect(recipe.dose == standard.dose)
      #expect(recipe.cooler.temperature == room)
      // Beaker A takes what beaker B gives up, so the pour still adds up.
      let split = recipe.kettleFill.demineralized + recipe.cooler.amount
      #expect(abs(split - (standard.kettleFill.demineralized + standard.cooler.amount)) < 1)
    }
  }

  /// A room at or above the target leaves no cold water able to cool
  /// anything, so the pour goes in hot rather than dividing by zero.
  @Test("A room as warm as the target pours everything hot")
  func roomAtTheTarget() {
    let hopeless = Recipe.switchWaterAndTempManaged(for: BrewSettings(roomTemperature: 80))

    #expect(hopeless.cooler.amount == 0)
  }

  /// The one measurement everything else is stretched from: 92 set, 85.5 when
  /// the cold water goes in, at one serving into a 20 degree room.
  @Test("One serving still drops the measured 6.5")
  func anchoredToTheMeasurement() {
    let drop = Scaling.temperatureDrop(water: Scaling.water(servings: 1), brewTemperature: 92)

    #expect(abs(drop - Scaling.referenceDrop) < 0.001)
    #expect(abs(Recipe.switchWaterAndTempManaged(
      for: .documented
    ).kettleTemperatureAtLastPour - 85.5) < 0.001
    )
  }

  /// More water is more to cool, so a bigger batch falls less. The
  /// spreadsheet types 85.5 into every row, which cannot be right.
  @Test("A bigger batch falls less")
  func biggerBatchesFallLess() throws {
    let drops = (1 ... 5).map {
      Scaling.temperatureDrop(water: Scaling.water(servings: $0), brewTemperature: 92)
    }

    for (bigger, smaller) in zip(drops, drops.dropFirst()) {
      #expect(smaller < bigger)
    }
    #expect(try #require(drops.last) > 2)
  }

  /// A kettle set lower starts closer to the room, so it has less to lose.
  @Test("A cooler kettle falls less")
  func coolerKettleFallsLess() {
    let water = Scaling.water(servings: 1)

    #expect(
      Scaling.temperatureDrop(water: water, brewTemperature: 85)
        < Scaling.temperatureDrop(water: water, brewTemperature: 92)
    )
    #expect(
      Scaling.temperatureDrop(water: water, brewTemperature: 96)
        > Scaling.temperatureDrop(water: water, brewTemperature: 92)
    )
  }

  /// A kettle already at room temperature has nothing to lose.
  @Test("A kettle at room temperature does not fall")
  func nothingToLose() {
    #expect(Scaling.temperatureDrop(water: 250, brewTemperature: 20, room: 20) == 0)
  }

  /// The body is a third of what has to cool at one serving, so leaving it
  /// out would exaggerate how much a bigger batch helps.
  @Test("The kettle body counts as mass")
  func theKettleCounts() {
    #expect(Scaling.kettleThermalMass == 90)
    #expect(Scaling.kettleShareOfWater * Scaling.water(servings: 1) < 2 * Scaling.kettleThermalMass)
  }
}
