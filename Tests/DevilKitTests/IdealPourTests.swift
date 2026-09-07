@testable import DevilKit
import Testing

@Suite("The pour the recipe intends")
struct IdealPourTests {
  private let recipe = Recipe.switchWaterAndTempManaged

  /// The swirl is at 0:15, so the bloom has to be in by then.
  @Test("The bloom pours over fifteen seconds")
  func bloomTakesFifteen() {
    let bloom = recipe.steps.first { $0.poured > 0 }

    #expect(bloom?.pourSeconds == 15)
    #expect(recipe.steps.first { $0.title == "Swirl" }?.start.seconds == 15)
  }

  /// Every pour ramps over the seconds it takes and then holds flat, which is
  /// what a scale reads when you stop pouring.
  @Test("The curve ramps and holds, and ends on the whole brew")
  func shape() {
    let ideal = recipe.idealPour

    #expect(ideal.first == PourSample(seconds: 0, grams: 0))
    #expect(ideal.contains(PourSample(seconds: 15, grams: 50)))
    #expect(ideal.contains(PourSample(seconds: 30, grams: 50)))
    #expect(ideal.contains(PourSample(seconds: 45, grams: 100)))
    #expect(ideal.contains(PourSample(seconds: 60, grams: 100)))
    #expect(ideal.last?.seconds == Double(recipe.totalTime.seconds))
    #expect(ideal.last?.grams == recipe.waterThroughBed)
  }

  @Test("The curve never goes backwards, in time or in water")
  func monotonic() {
    for servings in 1 ... 5 {
      let ideal = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: servings)).idealPour
      for (earlier, later) in zip(ideal, ideal.dropFirst()) {
        #expect(later.seconds >= earlier.seconds)
        #expect(later.grams >= earlier.grams)
      }
    }
  }

  /// A step that pours nothing has no duration to draw.
  @Test("Only the pours have a duration")
  func onlyPoursTakeTime() {
    for step in recipe.steps {
      #expect((step.poured > 0) == (step.pourSeconds > 0))
    }
  }

  /// The clock is the same at every size, so a bigger bloom goes in faster
  /// rather than later. A fixed rate would push the pour past its own swirl.
  @Test("A bigger brew pours faster, not longer")
  func biggerPoursFaster() throws {
    let four = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: 4))
    let bloom = four.steps.first { $0.poured > 0 }

    #expect(bloom?.pourSeconds == 15)
    #expect(try #require(bloom?.poured) > recipe.steps.first { $0.poured > 0 }!.poured)
    #expect(Scaling.pourRate(servings: 4) > Scaling.pourRate(servings: 1))
  }

  /// The ideal has to end where the running total does, or the two lines on
  /// the graph would disagree about the same brew.
  @Test("The curve agrees with the running target at every size")
  func agreesWithTheTarget() throws {
    for servings in 1 ... 5 {
      let recipe = Recipe.switchWaterAndTempManaged(for: BrewSettings(servings: servings))
      let last = try #require(recipe.steps.sorted { $0.start < $1.start }.last)

      #expect(recipe.idealPour.last?.grams == recipe.cumulativeTarget(through: last))
    }
  }
}
