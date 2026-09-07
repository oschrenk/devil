@testable import DevilKit
import Testing

@Suite("Schedule")
struct ScheduleTests {
  let recipe = Recipe.switchWaterAndTempManaged

  @Test("The schedule runs 0:00 to 3:15 in seven steps")
  func shape() {
    #expect(recipe.steps.count == 7)
    #expect(recipe.steps.first?.start == BrewTime(minutes: 0, seconds: 0))
    #expect(recipe.totalTime == BrewTime(minutes: 3, seconds: 15))
  }

  @Test("Every step names a switch position, and the recipe flips it three times")
  func switchPositions() {
    let positions = recipe.steps.map(\.switchPosition)

    #expect(positions == [.closed, .closed, .open, .open, .closed, .open, .open])

    let flips = zip(positions, positions.dropFirst()).count { $0 != $1 }
    #expect(flips == 3)
  }

  @Test("Steps run in clock order")
  func ordering() {
    let starts = recipe.steps.map(\.start)
    #expect(starts == starts.sorted())
  }

  @Test("Durations fall out of the absolute times")
  func durations() {
    let durations = recipe.steps.map { recipe.duration(of: $0) }

    #expect(durations == [15, 15, 30, 45, 45, 45, nil])
  }

  @Test("The current step is the last one that has started")
  func currentStep() {
    #expect(recipe.step(atSeconds: 0)?.title == "Bloom")
    #expect(recipe.step(atSeconds: 29)?.title == "Swirl")
    #expect(recipe.step(atSeconds: 30)?.title == "Pour 2")
    #expect(recipe.step(atSeconds: 110)?.title == "Cold add and swirl")
    #expect(recipe.step(atSeconds: 195)?.title == "Done")
    #expect(recipe.step(atSeconds: 999)?.title == "Done")
  }

  @Test("The bloom is an immersion, and the second pour percolates")
  func immersionThenPercolation() {
    let bloom = recipe.steps[0]
    #expect(bloom.switchPosition == .closed)
    #expect(bloom.poured == 50)

    let second = recipe.steps[2]
    #expect(second.switchPosition == .open)
    #expect(second.poured == 50)
  }

  @Test("The cold add goes into the kettle, and the bed gets 75 g")
  func coldAddStep() {
    let step = recipe.steps[4]

    #expect(step.start == BrewTime(minutes: 1, seconds: 45))
    #expect(step.switchPosition == .closed)
    #expect(step.coolerAdded == 12)
    #expect(step.poured == 75)
    #expect(step.actions.contains(.swirl))
  }
}
