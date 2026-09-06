@testable import DevilKit
import Testing

@Suite("Scale control")
struct ScaleControlTests {
  /// The check the whole task turns on. A scale that goes out of range reports
  /// no press, and a brew must survive losing Bluetooth.
  @Test("No press is not a stop")
  func absenceIsNotAStop() {
    #expect(ScaleControl.reaction(to: nil, clockIsHeld: false) == .doNothing)
    #expect(ScaleControl.reaction(to: nil, clockIsHeld: true) == .doNothing)
  }

  @Test("A stop holds the clock")
  func stopHolds() {
    #expect(ScaleControl.reaction(to: .stop, clockIsHeld: false) == .holdTheClock)
  }

  /// The scale tells the two apart, so this is a choice rather than a limit.
  @Test("A reset is not a stop, and neither is a start or a tare")
  func otherButtons() {
    #expect(ScaleControl.reaction(to: .reset, clockIsHeld: false) == .doNothing)
    #expect(ScaleControl.reaction(to: .start, clockIsHeld: false) == .doNothing)
    #expect(ScaleControl.reaction(to: .tare, clockIsHeld: false) == .doNothing)
  }

  /// The app sends a start at 0:00 and the scale answers with a start press.
  /// Nothing here must turn that echo into an action.
  @Test("An already-held clock is left alone")
  func heldClockIsLeftAlone() {
    for button in [AcaiaButton.stop, .reset, .start, .tare] {
      #expect(ScaleControl.reaction(to: button, clockIsHeld: true) == .doNothing)
    }
  }
}
