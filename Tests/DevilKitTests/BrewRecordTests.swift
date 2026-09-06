@testable import DevilKit
import Testing

@Suite("Brew record")
struct BrewRecordTests {
  private var stamp: BrewStamp {
    BrewStamp(year: 2026, month: 9, day: 6, hour: 7, minute: 14, utcOffsetMinutes: 120)
  }

  private func record(notes: String = "") -> BrewRecord {
    var record = BrewRecord.of(
      settings: BrewSettings(servings: 1),
      at: stamp,
      finished: true,
      trace: "2026-09-06T0714.json"
    )
    record.notes = notes
    return record
  }

  /// The `T` separates date from time. A second dash reads as another part of
  /// the date, and a colon is illegal in a filename.
  @Test("A brew names its files after the minute it started")
  func stem() {
    #expect(stamp.stem == "2026-09-06T0714")
    #expect(BrewStamp(year: 2026, month: 12, day: 31, hour: 0, minute: 5).stem == "2026-12-31T0005")
    #expect(stamp.readable == "2026-09-06 07:14")
    #expect(stamp.timestamp == "2026-09-06T07:14:00+02:00")
  }

  @Test("A record survives the trip to markdown and back")
  func roundTrip() {
    let original = record()

    #expect(BrewRecord.parse(markdown: original.markdown) == original)
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

    #expect(lines.contains("- Grind Size: 7.9 (613 \u{00B5}m)"))
    #expect(lines.contains("grind: 7.9"))
    #expect(lines.contains("grindMicrons: 613"))
    #expect(lines.contains("- Temperature: 92 °C"))
    #expect(lines.contains("- Yield: 250 g"))
    #expect(lines.contains("- Weight: 15 g"))
    #expect(lines.contains("- Recipe: #recipe/hario-switch"))
    #expect(lines.contains("- Grinder: 1Zpresso K-Ultra"))
  }

  /// A blank line is not a fact, and a form nobody can fill in yet is noise
  /// in every brew ever written.
  @Test("A field with no answer is left out")
  func blankFieldsAreOmitted() {
    let blank = record().markdown

    #expect(!blank.contains("Aroma"))
    #expect(!blank.contains("Beans"))
    #expect(!blank.contains("Total Dissolved Solids"))
    for line in blank.split(separator: "\n", omittingEmptySubsequences: false) {
      #expect(line == line.reversed().drop { $0 == " " }.reversed().map(String.init).joined())
    }
  }

  @Test("A brew with nothing typed states only what the app measured")
  func bodyOrder() {
    let labels = record().markdown
      .split(separator: "\n")
      .filter { $0.hasPrefix("- ") }
      .compactMap { $0.dropFirst(2).split(separator: ":").first.map(String.init) }

    #expect(labels == [
      "Recipe", "Grinder", "Grind Size", "Temperature", "Yield", "Weight",
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
        case "- Grind Size: 7.9 (613 \u{00B5}m)": "- Grind Size: 8.4 (guessed)"
        case "- Yield: 250 g": "- Yield: about a cup"
        default: String(line)
        }
      }
      .joined(separator: "\n")

    let parsed = BrewRecord.parse(markdown: edited)

    #expect(parsed?.grind == "7.9")
    #expect(parsed?.grindMicrons == 613)
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
