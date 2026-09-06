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

  /// Exactly one command, so the scale beeps once at the moment the pouring
  /// starts. The reset goes out three seconds earlier, when the button is
  /// pressed.
  @Test("A single start goes out at 0:00")
  func sendsAtZero() {
    var signal = BrewStartSignal()

    #expect(signal.commands(elapsed: 0) == [.startTimer])
    #expect(signal.hasSent)
  }

  /// The screen redraws every second. Without the memory this would send a
  /// reset and a start on every one of them, restarting the scale for ever.
  @Test("It sends once, however many times the screen redraws")
  func sendsOnlyOnce() {
    var signal = BrewStartSignal()
    let ticks = stride(from: -3.0, through: 200.0, by: 0.5)
    let sent = ticks.flatMap { signal.commands(elapsed: $0) }

    #expect(sent == [.startTimer])
  }

  /// A brew joined late, because the app was reopened mid-brew, still needs
  /// the scale told once.
  @Test("A clock that starts past zero still sends once")
  func startsLate() {
    var signal = BrewStartSignal()

    #expect(signal.commands(elapsed: 42) == [.startTimer])
    #expect(signal.commands(elapsed: 43).isEmpty)
  }
}
