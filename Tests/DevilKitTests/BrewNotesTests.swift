@testable import DevilKit
import Testing

@Suite("Brew notes")
struct BrewNotesTests {
  private var record: BrewRecord {
    BrewRecord.of(
      settings: BrewSettings(servings: 1),
      at: BrewStamp(year: 2026, month: 9, day: 6, hour: 7, minute: 14),
      finished: true
    )
  }

  @Test("A brew with nothing typed states only what the app measured")
  func bodyWithoutNotes() {
    let labels = record.markdown
      .split(separator: "\n")
      .filter { $0.hasPrefix("- ") }
      .compactMap { $0.dropFirst(2).split(separator: ":").first.map(String.init) }

    #expect(labels == ["Recipe", "Grinder", "Grind Size", "Temperature", "Yield", "Weight"])
    #expect(!record.markdown.contains("Aroma"))
  }

  @Test("A note survives the trip to markdown and back")
  func roundTrip() {
    var original = record
    original.notes = "Guji, washed. Second time on this bag."

    let parsed = BrewRecord.parse(markdown: original.markdown)

    #expect(parsed == original)
    #expect(parsed?.notes == "Guji, washed. Second time on this bag.")
  }

  /// A note is prose, so it runs to as many lines as it needs.
  @Test("A note keeps its line breaks and its blank lines")
  func multipleLines() {
    var original = record
    original.notes = "Jasmine, peach.\n\nToo fast a drawdown. Grind finer next time."

    let parsed = BrewRecord.parse(markdown: original.markdown)

    #expect(parsed?.notes == original.notes)
  }

  @Test("Writing a note leaves the frontmatter and the bullets alone")
  func applyKeepsEverythingAbove() {
    let edited = BrewRecord.apply("Tasted thin.", to: record.markdown)
    let before = record.markdown.split(separator: "\n").filter { !$0.isEmpty }
    let after = edited.split(separator: "\n").filter { !$0.isEmpty }

    #expect(Array(after.dropLast()) == Array(before))
    #expect(after.last == "Tasted thin.")
    #expect(BrewRecord.parse(markdown: edited)?.grind == 7.9)
  }

  @Test("Writing a second note replaces the first")
  func applyReplaces() {
    let once = BrewRecord.apply("Thin.", to: record.markdown)
    let twice = BrewRecord.apply("Better, ground finer.", to: once)

    #expect(!twice.contains("Thin."))
    #expect(twice.contains("Better, ground finer."))
    #expect(BrewRecord.parse(markdown: twice)?.notes == "Better, ground finer.")
  }

  @Test("Clearing a note leaves the file as it started")
  func applyClears() {
    let once = BrewRecord.apply("Thin.", to: record.markdown)

    #expect(BrewRecord.apply("", to: once) == record.markdown)
  }

  /// The app writes the bullets, so everything under them is yours. A heading
  /// added in Obsidian reads into the editor and goes out again unchanged.
  @Test("A heading written by hand reads back as part of the note")
  func keepsHandWrittenProse() {
    let byHand = record.markdown + "\n## Tasting\n\nGuji, washed.\n"

    let parsed = BrewRecord.parse(markdown: byHand)

    #expect(parsed?.notes == "## Tasting\n\nGuji, washed.")
    #expect(BrewRecord.apply(parsed.map(\.notes) ?? "", to: byHand).contains("## Tasting"))
  }

  @Test("A file with no bullets is left alone rather than mangled")
  func refusesToGuess() {
    #expect(BrewRecord.apply("hello", to: "---\nbrewed: x\n---\n") == "---\nbrewed: x\n---\n")
  }
}
