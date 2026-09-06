@testable import DevilKit
import Testing

@Suite("Brew clock")
struct BrewClockTests {
  @Test("An untouched clock reads the raw seconds")
  func passesThrough() {
    let clock = BrewClock()

    #expect(clock.elapsed(raw: 0) == 0)
    #expect(clock.elapsed(raw: 42.5) == 42.5)
    #expect(clock.isHeld == false)
  }

  /// The check that matters: the clock stops, and picks up where it stopped.
  @Test("A hold freezes the clock, and releasing resumes from the same second")
  func holdAndRelease() {
    var clock = BrewClock()
    clock.hold(raw: 10)

    #expect(clock.isHeld)
    #expect(clock.elapsed(raw: 10) == 10)
    #expect(clock.elapsed(raw: 70) == 10)

    clock.release(raw: 70)

    #expect(clock.isHeld == false)
    #expect(clock.elapsed(raw: 70) == 10)
    #expect(clock.elapsed(raw: 71) == 11)
  }

  @Test("Holds accumulate across a brew")
  func repeatedHolds() {
    var clock = BrewClock()
    clock.hold(raw: 10)
    clock.release(raw: 20)
    clock.hold(raw: 30)
    clock.release(raw: 45)

    #expect(clock.heldTotal == 25)
    #expect(clock.elapsed(raw: 45) == 20)
  }

  /// A repeated tap must not move the moment the first one recorded, or the
  /// clock would creep forward every time a wet finger lands twice.
  @Test("Holding twice keeps the first moment, and releasing twice adds nothing")
  func repeatedTaps() {
    var clock = BrewClock()
    clock.hold(raw: 10)
    clock.hold(raw: 40)

    #expect(clock.elapsed(raw: 40) == 10)

    clock.release(raw: 70)
    clock.release(raw: 100)

    #expect(clock.heldTotal == 60)
    #expect(clock.elapsed(raw: 100) == 40)
  }

  /// Raw seconds run negative through the lead-in, so a hold there needs no
  /// special case: 0:00 arrives later by exactly the time held.
  @Test("A hold during the countdown delays 0:00 by the time held")
  func holdDuringTheCountdown() {
    var clock = BrewClock()
    clock.hold(raw: -3)

    #expect(clock.elapsed(raw: -3) == -3)
    #expect(clock.elapsed(raw: 57) == -3)

    clock.release(raw: 57)

    #expect(clock.heldTotal == 60)
    #expect(clock.elapsed(raw: 60) == 0)
    #expect(clock.elapsed(raw: 61) == 1)
  }

  @Test("The schedule reports one step throughout a hold")
  func scheduleStandsStill() {
    let recipe = Recipe.switchWaterAndTempManaged
    var clock = BrewClock()
    clock.hold(raw: 35)

    let steps = stride(from: 35.0, through: 200.0, by: 5).map { raw in
      recipe.progress(atSeconds: Int(clock.elapsed(raw: raw))).step.title
    }

    #expect(steps.allSatisfy { $0 == "Pour 2" })
  }

  @Test("Releasing a clock that was never held changes nothing")
  func releaseWithoutHold() {
    var clock = BrewClock()
    clock.release(raw: 100)

    #expect(clock.heldTotal == 0)
    #expect(clock.elapsed(raw: 100) == 100)
  }
}

@Suite("Holding at a reported time")
struct BrewClockReportedTests {
  /// The scale's stop arrives a few seconds after the fact. Holding at its
  /// reading rather than at the moment of noticing keeps the clocks together.
  @Test("A hold can be placed at a time the scale reported")
  func holdsAtAReportedTime() {
    var clock = BrewClock()
    clock.hold(showing: 55)

    #expect(clock.isHeld)
    #expect(clock.elapsed(raw: 60) == 55)
    #expect(clock.elapsed(raw: 90) == 55)
  }

  @Test("Releasing continues from the reported time, not from where it was noticed")
  func resumesFromTheReportedTime() {
    var clock = BrewClock()
    clock.hold(showing: 55)
    clock.release(raw: 100)

    #expect(clock.elapsed(raw: 100) == 55)
    #expect(clock.elapsed(raw: 101) == 56)
  }

  /// Holding at the clock's own reading has to behave exactly as the plain
  /// hold does, because that is what the plain hold now is.
  @Test("A hold at the current reading matches an ordinary hold")
  func matchesAnOrdinaryHold() {
    var byRaw = BrewClock()
    var byReading = BrewClock()
    byRaw.hold(raw: 42)
    byReading.hold(showing: 42)

    #expect(byRaw == byReading)
  }

  @Test("Reported holds accumulate the same way across a brew")
  func repeatedReportedHolds() {
    var clock = BrewClock()
    clock.hold(showing: 20)
    clock.release(raw: 50)
    clock.hold(showing: 25)
    clock.release(raw: 90)

    #expect(clock.elapsed(raw: 90) == 25)
    #expect(clock.elapsed(raw: 95) == 30)
  }
}
