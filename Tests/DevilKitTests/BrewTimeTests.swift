@testable import DevilKit
import Testing

@Suite("BrewTime")
struct BrewTimeTests {
  @Test("Minutes and seconds convert to a single count")
  func minutesAndSeconds() {
    #expect(BrewTime(minutes: 1, seconds: 45).seconds == 105)
    #expect(BrewTime(minutes: 3, seconds: 30).seconds == 210)
  }

  @Test("Formatting pads the seconds, the way the recipe is written")
  func formatting() {
    #expect(BrewTime(minutes: 0, seconds: 0).formatted == "0:00")
    #expect(BrewTime(minutes: 0, seconds: 10).formatted == "0:10")
    #expect(BrewTime(minutes: 1, seconds: 45).formatted == "1:45")
    #expect(BrewTime(minutes: 3, seconds: 30).formatted == "3:30")
  }

  @Test("Times order by the clock")
  func ordering() {
    #expect(BrewTime(minutes: 0, seconds: 30) < BrewTime(minutes: 1, seconds: 0))
    #expect(BrewTime(seconds: 105) == BrewTime(minutes: 1, seconds: 45))
  }
}
