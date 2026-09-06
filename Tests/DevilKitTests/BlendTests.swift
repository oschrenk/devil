@testable import DevilKit
import Testing

@Suite("Blend")
struct BlendTests {
  @Test("A pour removes both waters in the ratio the blend holds")
  func pourIsProportional() {
    var blend = Blend(tap: 150, demineralized: 50)
    let poured = blend.pour(100)

    #expect(poured.total == 100)
    #expect(poured.tap == 75)
    #expect(poured.demineralized == 25)
    #expect(blend.tap == 75)
    #expect(blend.demineralized == 25)
  }

  @Test("What stays behind keeps the same ratio as what came out")
  func remainderKeepsTheRatio() {
    var blend = Blend(tap: 150, demineralized: 113)
    let poured = blend.pour(175)

    #expect(abs(poured.tapFraction - blend.tapFraction) < 0.000_001)
  }

  @Test("Adding demineralized water shifts the ratio")
  func addingShiftsTheRatio() {
    var blend = Blend(tap: 50, demineralized: 50)
    blend.addDemineralized(50)

    #expect(blend.total == 150)
    #expect(abs(blend.tapFraction - 1.0 / 3.0) < 0.000_001)
  }

  @Test("Pouring more than the blend holds empties it and returns the rest")
  func pouringPastEmpty() {
    var blend = Blend(tap: 10, demineralized: 10)
    let poured = blend.pour(100)

    #expect(poured.total == 20)
    #expect(blend.total == 0)
    #expect(blend.tapFraction == 0)
  }
}
