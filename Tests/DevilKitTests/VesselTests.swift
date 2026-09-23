@testable import DevilKit
import Testing

@Suite("Vessel")
struct VesselTests {
  private var stamp: BrewStamp {
    BrewStamp(year: 2026, month: 9, day: 6, hour: 7, minute: 14, utcOffsetMinutes: 120)
  }

  private func record(vessel: String? = nil, drink: Double? = nil) -> BrewRecord {
    var record = BrewRecord.of(
      settings: BrewSettings(servings: 1),
      at: stamp,
      finished: true,
      trace: "2026-09-06T0714.json"
    )
    record.vessel = vessel
    record.drink = drink
    return record
  }

  /// The table is the whole mechanism, so every row is checked rather than one.
  @Test("The drink is the total less the vessel, for every vessel there is")
  func everyVessel() {
    for vessel in Vessel.all {
      #expect(vessel.drink(total: vessel.weight + 245) == 245)
    }
    #expect(Vessel.all.count == 7)
    #expect(Vessel.all[0] == .hario600)
    #expect(Vessel.hario600.weight == 203.4)
  }

  /// A carafe on an untared scale, or the wrong vessel picked. Minus 153 g is
  /// a worse answer than none.
  @Test("A total under the vessel produces nothing rather than a negative")
  func tooLight() {
    #expect(Vessel.hario600.drink(total: 50) == nil)
    #expect(Vessel.hario600.drink(total: 203.4) == nil)
    #expect(Vessel.hario600.drink(total: 203.5) == 0.1)
  }

  @Test("A weighed brew survives the trip to markdown and back")
  func roundTrip() {
    let weighed = record(vessel: "Hario 600 ml", drink: 245.6)
    #expect(BrewRecord.parse(markdown: weighed.markdown) == weighed)
    // And a brew nobody weighed writes neither key.
    let unweighed = record()
    #expect(!unweighed.markdown.contains("vessel:"))
    #expect(!unweighed.markdown.contains("drink:"))
    #expect(BrewRecord.parse(markdown: unweighed.markdown) == unweighed)
  }

  @Test("The sidecar carries the vessel and the drink")
  func sidecar() {
    let json = record(vessel: "Sama Doyo", drink: 245.6).json(trace: PourTrace())
    #expect(json.contains("\"vessel\": \"Sama Doyo\""))
    #expect(json.contains("\"drink\": 245.6"))
    #expect(!record().json(trace: PourTrace()).contains("\"drink\""))
  }

  /// The note below the bullets is yours, and changing a number above it must
  /// not touch it.
  @Test("Writing a weight into a file leaves the note alone")
  func surgical() {
    let file = record().markdown + "\nTasted of blackcurrant.\n"
    let edited = BrewRecord.applyDrink(vessel: "Hario 600 ml", drink: 245.6, to: file)
    #expect(edited.contains("Tasted of blackcurrant."))
    #expect(BrewRecord.parse(markdown: edited)?.drink == 245.6)
    #expect(BrewRecord.parse(markdown: edited)?.vessel == "Hario 600 ml")
  }

  /// A vessel picked wrong is the reason to weigh twice.
  @Test("Weighing again replaces the first answer rather than repeating it")
  func replaces() {
    let once = BrewRecord.applyDrink(vessel: "Sama Doyo", drink: 100, to: record().markdown)
    let twice = BrewRecord.applyDrink(vessel: "Hario 600 ml", drink: 245.6, to: once)
    #expect(twice.components(separatedBy: "drink:").count == 2)
    #expect(twice.components(separatedBy: "vessel:").count == 2)
    #expect(BrewRecord.parse(markdown: twice)?.drink == 245.6)
  }
}
