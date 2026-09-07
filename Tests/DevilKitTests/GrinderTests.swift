@testable import DevilKit
import Testing

@Suite("Grinder")
struct GrinderTests {
  private let kUltra = Grinder.oneZpressoKUltra
  private let ode = Grinder.fellowOdeSSP

  /// Checked against the converter these numbers came from. The K-Ultra is
  /// the grinder those figures describe, so it matches them exactly.
  @Test("The K-Ultra matches the published figures")
  func matchesPublishedFigures() {
    #expect(Int(kUltra.micron(at: GrindSetting(number: 7, click: 9)).rounded()) == 613)
    #expect(Int(kUltra.micron(at: GrindSetting(number: 5, click: 0)).rounded()) == 380)
  }

  /// The one point Oliver ground and compared. Everything about this Ode's
  /// size rests on it, so it is the assertion that matters most here.
  @Test("Seven six on the K-Ultra is nine one on the Ode")
  func calibration() {
    let size = kUltra.micron(at: GrindSetting(number: 7, click: 6))

    #expect(Int(size.rounded()) == 583)
    #expect(kUltra.setting(forMicron: size).formatted == "7.6")
    #expect(ode.setting(forMicron: size).formatted == "9.1")
    #expect(abs(size - BrewSettings.defaultMicrons) < 0.5)
  }

  /// The published figures describe stock burrs and this Ode wears SSP ones,
  /// so its dial reads a little under half of what they claim.
  @Test("The Ode is scaled off the published figures, not equal to them")
  func odeIsScaled() {
    let published = 970.0

    #expect(ode.micron(at: GrindSetting(number: 6, click: 0)) < published)
    #expect(Int(ode.micron(at: GrindSetting(number: 6, click: 0)).rounded()) == 461)
    #expect(Int(ode.micron(at: GrindSetting(number: 9, click: 0)).rounded()) == 566)
  }

  @Test("Each dial runs from its finest to its coarsest")
  func endsOfTheDial() {
    #expect(kUltra.micron(at: GrindSetting(number: 0, click: 0)) == 0)
    #expect(kUltra.micron(at: GrindSetting(number: 10, click: 0)) == 760)
    #expect(Int(ode.micron(at: GrindSetting(number: 1, click: 0)).rounded()) == 262)
    #expect(Int(ode.micron(at: GrindSetting(number: 11, click: 2)).rounded()) == 666)
  }

  /// The Ode has three clicks to a number, so `2.5` is not a setting. Stepping
  /// a decimal by a tenth would have offered detents it does not have.
  @Test("A dial only reports detents it has")
  func onlyRealDetents() {
    for micron in stride(from: 550.0, through: 1400.0, by: 7) {
      #expect(ode.setting(forMicron: micron).click < 3)
      #expect((1 ... 11).contains(ode.setting(forMicron: micron).number))
    }
    for micron in stride(from: 0.0, through: 760.0, by: 7) {
      #expect(kUltra.setting(forMicron: micron).click < 10)
      #expect((0 ... 10).contains(kUltra.setting(forMicron: micron).number))
    }
  }

  @Test("A size and its detent agree in both directions")
  func roundTrip() {
    // Numbers 0 to 9 with all ten clicks, since 10 is the last number and
    // carries only its first click.
    for number in 0 ... 9 {
      for click in 0 ..< 10 {
        let setting = GrindSetting(number: number, click: click)
        let size = kUltra.micron(at: setting)
        #expect(kUltra.setting(forMicron: size) == setting)
      }
    }
    for number in 1 ... 10 {
      for click in 0 ..< 3 {
        let setting = GrindSetting(number: number, click: click)
        #expect(ode.setting(forMicron: ode.micron(at: setting)) == setting)
      }
    }
  }

  /// The last number has only its first click, because the dial stops there.
  @Test("A click past the end of the dial stays at the end")
  func pastTheEnd() {
    #expect(kUltra.micron(at: GrindSetting(number: 10, click: 5)) == 760)
    #expect(ode.micron(at: GrindSetting(number: 11, click: 5)) == ode.micronRange.upperBound)
  }

  /// The two overlap only between 550 and 760 microns, so a size set for one
  /// can be off the end of the other.
  /// Scaling the Ode moved the overlap. The two used to share only 550 to
  /// 760 microns; they now share almost the whole of the Ode's dial.
  @Test("A grinder says what it cannot reach")
  func outOfRange() {
    #expect(kUltra.canReach(583))
    #expect(!kUltra.canReach(900))
    #expect(ode.canReach(583))
    #expect(!ode.canReach(200))
    #expect(!ode.canReach(700))
    #expect(kUltra.micronRange == 0 ... 760)
    #expect(Int(ode.micronRange.lowerBound.rounded()) == 262)
    #expect(Int(ode.micronRange.upperBound.rounded()) == 666)
  }

  @Test("A size past either end clamps to that end")
  func clamps() {
    #expect(kUltra.setting(forMicron: 5000) == GrindSetting(number: 10, click: 0))
    #expect(ode.setting(forMicron: -20) == GrindSetting(number: 1, click: 0))
    #expect(ode.setting(forMicron: 5000) == GrindSetting(number: 11, click: 2))
  }

  @Test("A dial reads as number and click")
  func formatting() {
    #expect(GrindSetting(number: 7, click: 9).formatted == "7.9")
    #expect(GrindSetting(number: 2, click: 0).formatted == "2.0")
    #expect(kUltra.setting(forMicron: 613).formatted == "7.9")
    #expect(kUltra.setting(forMicron: 583).formatted == "7.6")
  }

  /// Both grinders reach it, which is what makes one number usable for both.
  @Test("The same size lands on each grinder's own dial")
  func acrossGrinders() {
    let size = kUltra.micron(at: GrindSetting(number: 7, click: 6))

    #expect(ode.setting(forMicron: size).formatted == "9.1")
    #expect(Grinder.all.count == 2)
  }

  /// A click near the middle of a dial moves the grind several times further
  /// than one near an end, so stepping in microns would be arbitrary.
  @Test("Stepping moves by the grinder's own detents")
  func stepping() {
    let start = kUltra.micron(at: GrindSetting(number: 7, click: 9))

    #expect(kUltra.setting(forMicron: kUltra.stepped(start, by: 1)).formatted == "8.0")
    #expect(kUltra.setting(forMicron: kUltra.stepped(start, by: -1)).formatted == "7.8")
    #expect(kUltra.setting(forMicron: kUltra.stepped(start, by: 10)).formatted == "8.9")
    #expect(ode.setting(forMicron: ode.stepped(700, by: 1)).click < 3)
  }

  @Test("Stepping past either end of the dial stops there")
  func steppingClamps() {
    #expect(kUltra.stepped(760, by: 5) == 760)
    #expect(kUltra.stepped(0, by: -5) == 0)
    #expect(ode.stepped(ode.micronRange.upperBound, by: 3) == ode.micronRange.upperBound)
    #expect(ode.stepped(ode.micronRange.lowerBound, by: -3) == ode.micronRange.lowerBound)
  }
}
