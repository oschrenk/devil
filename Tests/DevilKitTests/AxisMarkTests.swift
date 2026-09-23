@testable import DevilKit
import Testing

@Suite("Labelled step times")
struct AxisMarkTests {
  private var recipe: Recipe {
    Recipe.switchWaterAndTempManaged(for: .documented)
  }

  /// The swirl sits ten seconds after the first pour, and on a phone the two
  /// labels overlap into a smear.
  @Test("Steps too close to the last label are dropped")
  func dropsCrowdedSteps() {
    let times = recipe.labelledStepTimes(minimumGap: 25)

    #expect(times.contains(0))
    #expect(!times.contains(10))
    for (earlier, later) in zip(times, times.dropFirst()) {
      #expect(later - earlier >= 25)
    }
  }

  @Test("Every label is a real step time")
  func labelsAreStepTimes() {
    let starts = Set(recipe.steps.map(\.start.seconds))

    for servings in 1 ... 5 {
      let recipe = Recipe.switchWaterAndTempManaged(
        for: BrewSettings.documented(servings: servings)
      )
      let times = recipe.labelledStepTimes(minimumGap: 25)
      #expect(!times.isEmpty)
      #expect(times.allSatisfy { Set(recipe.steps.map(\.start.seconds)).contains($0) })
      #expect(times == times.sorted())
    }
    #expect(starts.contains(0))
  }

  @Test("A gap of zero keeps every step")
  func keepsEverything() {
    #expect(recipe.labelledStepTimes(minimumGap: 0).count == recipe.steps.count)
  }
}
