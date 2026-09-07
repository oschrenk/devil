@testable import DevilKit
import Testing

@Suite("Brew record JSON")
struct BrewRecordJSONTests {
  private var record: BrewRecord {
    BrewRecord.of(
      settings: BrewSettings(servings: 1),
      at: BrewStamp(year: 2026, month: 9, day: 6, hour: 7, minute: 14, utcOffsetMinutes: 120),
      finished: true
    )
  }

  private var json: String {
    record.json(trace: PourTrace())
  }

  /// The sidecar has to explain itself to whatever reads it next, which is
  /// why it repeats what the markdown already says.
  @Test("The sidecar states what the brew was")
  func statesTheFacts() {
    #expect(json.contains("\"brew\": \"2026-09-06T0714\""))
    #expect(json.contains("\"brewed\": \"2026-09-06T07:14:00+02:00\""))
    #expect(json.contains("\"recipe\": \"Hario Switch, Water and Temp Managed\""))
    #expect(json.contains("\"servings\": 1"))
    #expect(json.contains("\"dose\": 15"))
    #expect(json.contains("\"water\": 250"))
    #expect(json.contains("\"grind\": \"7.9\""))
    #expect(json.contains("\"grindMicrons\": 613"))
    #expect(json.contains("\"grinder\": \"1Zpresso K-Ultra\""))
    #expect(json.contains("\"filter\": \"Hario V60, Natural\""))
    #expect(json.contains("\"brewTemperature\": 92"))
    #expect(json.contains("\"temperatureTarget\": 75"))
    #expect(json.contains("\"beakerA\": 107"))
    #expect(json.contains("\"beakerB\": 18"))
    #expect(json.contains("\"finished\": true"))
  }

  /// Thousands of times longer than everything above it, so a reader opening
  /// the file sees what the brew was before the wall of numbers.
  @Test("The readings come last")
  func samplesLast() throws {
    let samples = try #require(json.range(of: "\"samples\""))
    for name in ["brew", "recipe", "dose", "grinder", "finished"] {
      #expect(try #require(json.range(of: "\"\(name)\"")?.lowerBound) < samples.lowerBound)
    }
  }

  @Test("A brew that stopped early says so")
  func unfinished() {
    var early = record
    early.finished = false

    #expect(early.json(trace: PourTrace()).contains("\"finished\": false"))
  }

  /// A gear name with a quote in it would otherwise end the string early and
  /// leave the file unreadable.
  @Test("A quote in a name does not break the file")
  func escaping() {
    var odd = record
    odd.grinder = "A \"quoted\" grinder"
    odd.filter = "back\\slash"

    let json = odd.json(trace: PourTrace())

    #expect(json.contains("\"grinder\": \"A \\\"quoted\\\" grinder\""))
    #expect(json.contains("\"filter\": \"back\\\\slash\""))
  }

  /// The reader looks for `"brew"`, and three other names start with those
  /// letters. The quotes are what keep them apart.
  @Test("The reader picks the brew rather than a field that starts like it")
  func brewNotBrewed() {
    var trace = PourTrace()
    trace.append(seconds: 0.1, grams: 0.4)

    let parsed = PourTrace.parse(json: record.json(trace: trace))

    #expect(parsed?.brew == "2026-09-06T0714")
    #expect(parsed?.trace.samples.count == 1)
  }

  @Test("The facts add little to the size of a whole brew")
  func size() {
    var trace = PourTrace()
    for tick in 0 ... 1950 {
      trace.append(seconds: Double(tick) / 10, grams: Double(tick) / 8)
    }

    #expect(record.json(trace: trace).utf8.count < 40000)
    #expect(json.utf8.count < 400)
  }
}
