@testable import DevilKit
import Testing

@Suite("Brew record")
struct BrewRecordTests {
  private var stamp: BrewStamp {
    BrewStamp(year: 2026, month: 9, day: 6, hour: 7, minute: 14, utcOffsetMinutes: 120)
  }

  private func record(notes: BrewNotes = BrewNotes()) -> BrewRecord {
    var record = BrewRecord.of(
      settings: BrewSettings(servings: 1),
      at: stamp,
      finished: true,
      trace: "2026-09-06-0714.json"
    )
    record.notes = notes
    return record
  }

  @Test("A record survives the trip to markdown and back")
  func roundTrip() {
    let original = record()

    #expect(BrewRecord.parse(markdown: original.markdown) == original)
  }

  /// A brew written this morning has nothing typed into it yet.
  @Test("A record with nothing typed survives the trip")
  func roundTripBlank() {
    let original = record(notes: BrewNotes(beans: "", waterRecipe: ""))

    #expect(BrewRecord.parse(markdown: original.markdown) == original)
  }

  /// Tasting notes are prose, so a colon inside one must not split the line.
  @Test("A record with every note filled survives the trip")
  func roundTripFilled() {
    let notes = BrewNotes(
      beans: "#beans/ethiopia-guji",
      waterRecipe: "#water/third-wave-half",
      totalDissolvedSolids: "1.38",
      concentration: "21.4",
      aroma: "jasmine: loud at first",
      flavour: "peach, black tea",
      aftertaste: "long",
      acidity: "malic",
      sweetness: "high",
      bitterness: "low",
      texture: "syrupy",
      afterfeel: "clean",
      balance: "tilted sweet"
    )
    let original = record(notes: notes)

    let parsed = BrewRecord.parse(markdown: original.markdown)

    #expect(parsed == original)
    #expect(parsed?.notes.aroma == "jasmine: loud at first")
  }

  @Test("A brew with no scale round-trips without a trace")
  func roundTripNoTrace() {
    var original = record()
    original.trace = nil

    let parsed = BrewRecord.parse(markdown: original.markdown)

    #expect(parsed == original)
    #expect(parsed?.trace == nil)
  }

  @Test("One serving writes a dose of 15 and 250 of water")
  func frontmatterNumbers() {
    let lines = record().markdown.split(separator: "\n").map(String.init)

    #expect(lines.contains("dose: 15"))
    #expect(lines.contains("water: 250"))
    #expect(lines.contains("servings: 1"))
    #expect(lines.contains("brewed: 2026-09-06T07:14:00+02:00"))
    #expect(lines.contains("finished: true"))
  }

  /// The body has to match the vault's own template, or it does not paste in.
  @Test("The body fills the lines the app knows")
  func bodyLines() {
    let lines = record().markdown.split(separator: "\n").map(String.init)

    #expect(lines.contains("- Grind Size: 7.9"))
    #expect(lines.contains("- Temperature: 92 °C"))
    #expect(lines.contains("- Yield: 250 g"))
    #expect(lines.contains("- Weight: 15 g"))
    #expect(lines.contains("- Recipe: #recipe/hario-switch"))
    #expect(lines.contains("- Grinder: 1Zpresso K-Ultra"))
  }

  /// The split stays in frontmatter, where it is a measurement rather than a
  /// claim about which water recipe you used.
  @Test("The body leaves the water recipe for you to type")
  func waterRecipeIsTyped() {
    let lines = record().markdown.split(separator: "\n").map(String.init)

    #expect(lines.contains("- Water Recipe: #water/"))
    #expect(lines.contains("beakerA: 107"))
    #expect(lines.contains("beakerB: 18"))
  }

  @Test("The body lists the vault's nineteen fields in its own order")
  func bodyOrder() {
    let labels = record().markdown
      .split(separator: "\n")
      .filter { $0.hasPrefix("- ") }
      .compactMap { $0.dropFirst(2).split(separator: ":").first.map(String.init) }

    #expect(labels == [
      "Beans", "Recipe", "Water Recipe", "Grinder", "Grind Size",
      "Total Dissolved Solids", "Temperature", "Yield", "Concentration",
      "Aroma", "Flavour", "Aftertaste", "Acidity", "Sweetness", "Bitterness",
      "Weight", "Texture", "Afterfeel", "Balance",
    ])
  }

  /// Frontmatter is the record. Rewording a bullet changes what you read in
  /// the vault and leaves what the app measured alone.
  @Test("A reworded body does not change what the app measured")
  func rewordedBody() {
    let edited = record().markdown
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { line -> String in
        switch line {
        case "- Grind Size: 7.9": "- Grind Size: 8.4 (guessed)"
        case "- Yield: 250 g": "- Yield: about a cup"
        default: String(line)
        }
      }
      .joined(separator: "\n")

    let parsed = BrewRecord.parse(markdown: edited)

    #expect(parsed?.grind == 7.9)
    #expect(parsed?.water == 250)
  }

  @Test("A file with no frontmatter parses to nothing")
  func rejectsRubbish() {
    #expect(BrewRecord.parse(markdown: "# just a note\n\n- Aroma: nice\n") == nil)
    #expect(BrewRecord.parse(markdown: "") == nil)
    #expect(BrewRecord.parse(markdown: "---\nservings: 1\n---\n") == nil)
  }

  @Test("Two servings write the larger dose")
  func twoServings() {
    let two = BrewRecord.of(settings: BrewSettings(servings: 2), at: stamp, finished: false)
    let lines = two.markdown.split(separator: "\n").map(String.init)

    #expect(lines.contains("dose: 22.5"))
    #expect(lines.contains("water: 375"))
    #expect(lines.contains("finished: false"))
    #expect(BrewRecord.parse(markdown: two.markdown) == two)
  }
}
