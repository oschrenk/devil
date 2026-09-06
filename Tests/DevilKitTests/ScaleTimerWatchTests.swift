@testable import DevilKit
import Testing

@Suite("Scale timer watch")
struct ScaleTimerWatchTests {
  /// One reading says nothing about whether it is moving.
  @Test("The answer is unknown until a second reading arrives")
  func unknownAtFirst() {
    var watch = ScaleTimerWatch()

    #expect(watch.isRunning == nil)
    let changed = watch.observe(seconds: 4.2)

    #expect(changed == false)
    #expect(watch.isRunning == nil)
  }

  @Test("A rising time is a running clock")
  func rising() {
    var watch = ScaleTimerWatch()
    watch.observe(seconds: 2)

    let changed = watch.observe(seconds: 4.5)

    #expect(changed)
    #expect(watch.isRunning == true)
  }

  /// The whole point. A press is invisible, so a repeated time is the signal.
  @Test("A repeated time is a stopped clock")
  func repeated() {
    var watch = ScaleTimerWatch()
    watch.observe(seconds: 2)
    watch.observe(seconds: 10.5)

    let changed = watch.observe(seconds: 10.5)

    #expect(changed)
    #expect(watch.isRunning == false)
  }

  @Test("A time that falls back is a reset, which is also not running")
  func reset() {
    var watch = ScaleTimerWatch()
    watch.observe(seconds: 30)
    watch.observe(seconds: 45)

    let changed = watch.observe(seconds: 0)

    #expect(changed)
    #expect(watch.isRunning == false)
  }

  /// Only the change is worth acting on. A brew would otherwise be paused
  /// again on every reading that arrives while it is already paused.
  @Test("Only the reading that changes the answer reports a change")
  func onlyTransitions() {
    var watch = ScaleTimerWatch()
    let readings = [0.0, 2.0, 4.0, 6.0, 6.0, 6.0, 6.0, 8.0, 10.0]
    var changed: [Bool] = []
    for reading in readings {
      changed.append(watch.observe(seconds: reading))
    }

    #expect(changed == [false, true, false, false, true, false, false, true, false])
  }

  @Test("A whole brew followed from the scale's own clock")
  func aWholeBrew() {
    var watch = ScaleTimerWatch()
    for seconds in stride(from: 0.0, through: 195.0, by: 2.5) {
      watch.observe(seconds: seconds)
    }

    #expect(watch.isRunning == true)

    watch.observe(seconds: 195)
    #expect(watch.isRunning == false)
  }
}

@Suite("Scale timer, paused against idle")
struct ScalePausedTests {
  /// The distinction that keeps a brew from holding the moment it starts. A
  /// scale sitting idle repeats zero, which is stopped but not paused.
  @Test("A repeated zero is idle, not paused")
  func idleIsNotPaused() {
    var watch = ScaleTimerWatch()
    watch.observe(seconds: 0)
    watch.observe(seconds: 0)

    #expect(watch.isRunning == false)
    #expect(watch.hasPaused == false)
  }

  @Test("A repeated time above zero is a paused clock")
  func stoppedMidBrew() {
    var watch = ScaleTimerWatch()
    watch.observe(seconds: 40)
    watch.observe(seconds: 40)

    #expect(watch.hasPaused)
  }

  @Test("A running clock has not paused")
  func runningIsNotPaused() {
    var watch = ScaleTimerWatch()
    watch.observe(seconds: 40)
    watch.observe(seconds: 42)

    #expect(watch.hasPaused == false)
  }

  /// Someone resetting the scale mid-brew lands back at zero, which reads as
  /// idle rather than paused, and leaves the brew alone.
  @Test("A reset to zero reads as idle")
  func resetReadsAsIdle() {
    var watch = ScaleTimerWatch()
    watch.observe(seconds: 40)
    watch.observe(seconds: 0)

    #expect(watch.isRunning == false)
    #expect(watch.hasPaused == false)
  }
}
