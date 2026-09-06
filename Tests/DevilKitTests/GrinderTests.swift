@testable import DevilKit
import Testing

@Suite("Grinder")
struct GrinderTests {
  @Test("A brew grinds on the K-Ultra unless told otherwise")
  func defaultGrinder() {
    let settings = BrewSettings()

    #expect(settings.grinder == .oneZpressoKUltra)
    #expect(settings.grinder.name == "1Zpresso K-Ultra")
    #expect(settings.grindRange == 6.0 ... 10.0)
  }

  @Test("The dial the app offers is the dial the grinder has")
  func rangeFollowsGrinder() {
    var settings = BrewSettings()
    settings.use(.fellowOdeSSP)

    #expect(settings.grindRange == 1.0 ... 11.0)
    #expect(Grinder.all.count == 2)
  }

  /// A setting inside both dials is a setting the brewer chose, so changing
  /// burrs must not quietly move it.
  @Test("A setting both dials accept comes across unchanged")
  func keepsSettingInRange() {
    var settings = BrewSettings(grindSetting: 7.9)
    settings.use(.fellowOdeSSP)

    #expect(settings.grindSetting == 7.9)

    settings.use(.oneZpressoKUltra)

    #expect(settings.grindSetting == 7.9)
  }

  /// A number carried across unchanged would sit outside the new dial, and a
  /// stepper bounded by that dial could never reach it again.
  @Test("A setting the new dial cannot reach moves to its nearest end")
  func clampsSettingOutOfRange() {
    var settings = BrewSettings(grinder: .fellowOdeSSP, grindSetting: 2.5)

    #expect(settings.grindSetting == 2.5)

    settings.use(.oneZpressoKUltra)

    #expect(settings.grindSetting == 6.0)
  }

  @Test("A setting past the top of a dial moves down to it")
  func clampsAboveRange() {
    #expect(Grinder.oneZpressoKUltra.clamped(14) == 10)
    #expect(Grinder.oneZpressoKUltra.clamped(1) == 6)
    #expect(Grinder.fellowOdeSSP.clamped(14) == 11)
    #expect(Grinder.fellowOdeSSP.clamped(0.5) == 1)
    #expect(Grinder.fellowOdeSSP.clamped(7.9) == 7.9)
  }

  /// A grind number without its burrs records half a fact.
  @Test("The record states which burrs the number counts on")
  func recordCarriesGrinder() {
    let stamp = BrewStamp(year: 2026, month: 9, day: 6, hour: 7, minute: 14)
    var settings = BrewSettings()
    settings.use(.fellowOdeSSP)
    settings.grindSetting = 9.0

    let record = BrewRecord.of(settings: settings, at: stamp, finished: true)
    let lines = record.markdown.split(separator: "\n").map(String.init)

    #expect(record.grinder == "Fellow Ode with SSP")
    #expect(lines.contains("grinder: Fellow Ode with SSP"))
    #expect(lines.contains("- Grinder: Fellow Ode with SSP"))
    #expect(BrewRecord.parse(markdown: record.markdown) == record)
  }
}
