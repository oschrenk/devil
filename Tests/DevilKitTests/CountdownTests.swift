@testable import DevilKit
import Testing

@Suite("Countdown")
struct CountdownTests {
  /// Each number holds for a whole second, so 0:03 is on screen for as long as
  /// 0:02 is. A countdown that skipped straight to 2 would give a head start of
  /// two seconds while claiming three.
  @Test("Every number holds for a full second")
  func eachNumberHoldsASecond() {
    let shown = stride(from: 0.0, through: 2.9, by: 0.1).map { elapsed in
      Countdown.remaining(untilStart: 3 - elapsed)
    }

    #expect(shown.prefix(10).allSatisfy { $0 == 3 })
    #expect(shown.dropFirst(10).prefix(10).allSatisfy { $0 == 2 })
    #expect(shown.dropFirst(20).allSatisfy { $0 == 1 })
  }

  @Test("Zero means the brew has begun")
  func zeroAtTheStart() {
    #expect(Countdown.remaining(untilStart: 0) == 0)
    #expect(Countdown.remaining(untilStart: -0.5) == 0)
    #expect(Countdown.remaining(untilStart: -60) == 0)
  }

  @Test("The lead-in is three seconds")
  func leadIn() {
    #expect(Countdown.leadIn == 3)
    #expect(Countdown.remaining(untilStart: Double(Countdown.leadIn)) == 3)
  }
}
