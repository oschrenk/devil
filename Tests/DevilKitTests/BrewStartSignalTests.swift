@testable import DevilKit
import Testing

@Suite("Brew start signal")
struct BrewStartSignalTests {
  @Test("Nothing goes out during the countdown")
  func silentBeforeZero() {
    var signal = BrewStartSignal()

    #expect(signal.commands(elapsed: -3).isEmpty)
    #expect(signal.commands(elapsed: -2).isEmpty)
    #expect(signal.commands(elapsed: -0.5).isEmpty)
    #expect(signal.hasSent == false)
  }

  /// The reset matters as much as the start. A scale left running from an
  /// earlier brew would carry on from wherever it stopped.
  @Test("A reset then a start go out at 0:00")
  func sendsAtZero() {
    var signal = BrewStartSignal()

    #expect(signal.commands(elapsed: 0) == [.resetTimer, .startTimer])
    #expect(signal.hasSent)
  }

  /// The screen redraws every second. Without the memory this would send a
  /// reset and a start on every one of them, restarting the scale for ever.
  @Test("It sends once, however many times the screen redraws")
  func sendsOnlyOnce() {
    var signal = BrewStartSignal()
    let ticks = stride(from: -3.0, through: 200.0, by: 0.5)
    let sent = ticks.flatMap { signal.commands(elapsed: $0) }

    #expect(sent == [.resetTimer, .startTimer])
  }

  /// A brew joined late, because the app was reopened mid-brew, still needs
  /// the scale told once.
  @Test("A clock that starts past zero still sends once")
  func startsLate() {
    var signal = BrewStartSignal()

    #expect(signal.commands(elapsed: 42) == [.resetTimer, .startTimer])
    #expect(signal.commands(elapsed: 43).isEmpty)
  }
}
