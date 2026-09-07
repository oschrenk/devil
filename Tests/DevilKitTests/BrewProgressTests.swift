@testable import DevilKit
import Testing

@Suite("Brew progress")
struct BrewProgressTests {
  let recipe = Recipe.switchWaterAndTempManaged

  /// The check that matters: at no second between the first pour and the last
  /// drip is the app unsure what to do.
  @Test("Every second from 0 to 195 names exactly one step")
  func everySecondHasAStep() throws {
    let boundaries = [0, 15, 30, 60, 105, 150, 195]
    let titles = ["Bloom", "Swirl", "Pour 2", "Pour 3", "Cold add and swirl", "Drain", "Done"]

    for second in 0 ... 195 {
      let progress = recipe.progress(atSeconds: second)
      let expected = try #require(boundaries.lastIndex { $0 <= second })

      #expect(progress.stepIndex == expected)
      #expect(progress.step.title == titles[expected])
      #expect(progress.secondsIntoStep == second - boundaries[expected])
      #expect(progress.secondsIntoStep >= 0)
    }
  }

  @Test("A step begins on its own second, not the one after")
  func boundariesAreInclusive() {
    #expect(recipe.progress(atSeconds: 29).step.title == "Swirl")
    #expect(recipe.progress(atSeconds: 30).step.title == "Pour 2")
    #expect(recipe.progress(atSeconds: 104).step.title == "Pour 3")
    #expect(recipe.progress(atSeconds: 105).step.title == "Cold add and swirl")
  }

  @Test("The countdown runs to the next step and stops on the last")
  func countdown() {
    #expect(recipe.progress(atSeconds: 0).secondsUntilNextStep == 15)
    #expect(recipe.progress(atSeconds: 14).secondsUntilNextStep == 1)
    #expect(recipe.progress(atSeconds: 25).secondsUntilNextStep == 5)
    #expect(recipe.progress(atSeconds: 104).secondsUntilNextStep == 1)
    #expect(recipe.progress(atSeconds: 195).secondsUntilNextStep == nil)
    #expect(recipe.progress(atSeconds: 195).nextStep == nil)
  }

  @Test("Before the start and after the end it still says something")
  func outsideTheSchedule() {
    let before = recipe.progress(atSeconds: -30)
    #expect(before.step.title == "Bloom")
    #expect(before.elapsed == BrewTime(seconds: 0))
    #expect(before.isComplete == false)

    let after = recipe.progress(atSeconds: 600)
    #expect(after.step.title == "Done")
    #expect(after.isComplete)
    #expect(after.fraction == 1)
  }

  @Test("Completion lands on the finish, not before it")
  func completion() {
    #expect(recipe.progress(atSeconds: 194).isComplete == false)
    #expect(recipe.progress(atSeconds: 195).isComplete)
  }

  /// Five servings has no observed finish, so the schedule ends at the drain
  /// and the timer has to stop there rather than run to a made-up number.
  @Test("At a size nobody timed, the clock ends at the drain")
  func untimedSize() {
    let five = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: 5))

    #expect(five.progress(atSeconds: 150).step.title == "Drain")
    #expect(five.progress(atSeconds: 150).isComplete)
    #expect(five.progress(atSeconds: 149).isComplete == false)
  }
}

@Suite("Instructions")
struct InstructionTests {
  let recipe = Recipe.switchWaterAndTempManaged

  @Test("The bloom closes the switch before it pours")
  func bloom() {
    #expect(recipe.instructions(for: recipe.steps[0]) == ["Close the switch", "Pour 50 g"])
  }

  /// The Definition of Done for DEVIL-04 names this string.
  @Test("At 0:30 the app says to open the switch, then pour 50 g")
  func atThirtySeconds() {
    let step = recipe.progress(atSeconds: 30).step

    #expect(recipe.instructions(for: step) == ["Open the switch", "Pour 50 g"])
  }

  @Test("A step that does not move the switch does not mention it")
  func switchLineOnlyOnChange() {
    // Pour 3 follows Pour 2, both open.
    #expect(recipe.instructions(for: recipe.steps[3]) == ["Pour 75 g"])
    // The swirl follows the bloom, both closed.
    #expect(recipe.instructions(for: recipe.steps[1]) == ["Swirl"])
  }

  @Test("The cold add closes the switch, adds 12 g, pours and swirls")
  func coldAdd() {
    let step = recipe.progress(atSeconds: 105).step

    #expect(recipe.instructions(for: step) == [
      "Close the switch",
      "Add 12 g cold water to the kettle",
      "Pour 75 g",
      "Swirl",
    ])
  }

  @Test("Weights read the way the scale does, at every size")
  func weightsAtOtherSizes() {
    let two = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: 2))
    let step = two.progress(atSeconds: 60).step

    // 112.5 g keeps its decimal; 75 g does not gain one.
    #expect(two.instructions(for: step) == ["Pour 112.5 g"])
    #expect(Format.grams(75) == "75 g")
    #expect(Format.grams(112.5) == "112.5 g")
  }
}
