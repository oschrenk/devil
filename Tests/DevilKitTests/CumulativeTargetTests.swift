@testable import DevilKit
import Testing

@Suite("Cumulative target")
struct CumulativeTargetTests {
  let recipe = Recipe.switchWaterAndTempManaged(for: .documented)

  /// What the scale should read at the end of each step, which is what turns a
  /// weight readout into an instruction to stop pouring.
  @Test("One serving runs 50, 100, 175 then 250")
  func oneServing() {
    let targets = recipe.steps.map { recipe.cumulativeTarget(through: $0) }

    #expect(targets == [50, 50, 100, 175, 250, 250, 250])
  }

  /// A swirl pours nothing, so it names the figure the bloom reached. Without
  /// that the target would drop to zero mid-brew and the guidance would lie.
  @Test("A step that pours nothing inherits the total before it")
  func inherited() {
    let swirl = recipe.steps[1]
    let drain = recipe.steps[5]

    #expect(swirl.poured == 0)
    #expect(recipe.cumulativeTarget(through: swirl) == 50)
    #expect(drain.poured == 0)
    #expect(recipe.cumulativeTarget(through: drain) == 250)
  }

  @Test("Two servings runs 75, 150, 262.5 then 375")
  func twoServings() {
    let two = Recipe.switchWaterAndTempManaged(for: BrewSettings.documented(servings: 2))
    let targets = two.steps.map { two.cumulativeTarget(through: $0) }

    #expect(targets == [75, 75, 150, 262.5, 375, 375, 375])
  }

  /// The last target has to be the whole brew, at every size, or the app would
  /// tell you to stop short of the recipe.
  @Test("The final target is the water through the bed, at every size")
  func endsOnTheWholeBrew() throws {
    for servings in 1 ... 5 {
      let recipe = Recipe.switchWaterAndTempManaged(
        for: BrewSettings.documented(servings: servings)
      )
      let last = try #require(recipe.steps.max { $0.start < $1.start })

      #expect(recipe.cumulativeTarget(through: last) == recipe.waterThroughBed)
    }
  }

  @Test("The target never falls as the brew goes on")
  func neverFalls() {
    let targets = recipe.steps.map { recipe.cumulativeTarget(through: $0) }

    #expect(zip(targets, targets.dropFirst()).allSatisfy { $0 <= $1 })
  }
}
