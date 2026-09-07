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
    #expect(json.contains("\"brewed\": \"2026-09-06T07:14:00+02:00\""))
    #expect(json.contains("\"recipe\": \"Hario Switch, Water and Temp Managed\""))
    #expect(json.contains("\"servings\": 1"))
    #expect(json.contains("\"dose\": 15"))
    #expect(json.contains("\"water\": 250"))
    #expect(json.contains("\"grind\": \"7.6\""))
    #expect(json.contains("\"grindMicrons\": 583"))
    #expect(json.contains("\"grinder\": \"1Zpresso K-Ultra\""))
    #expect(json.contains("\"filter\": \"Hario V60, Natural\""))
    #expect(json.contains("\"brewTemperature\": 92"))
    #expect(json.contains("\"temperatureTarget\": 75"))
    #expect(json.contains("\"beakerA\": 107"))
    #expect(json.contains("\"beakerB\": 18"))
  }

  /// Thousands of times longer than everything above it, so a reader opening
  /// the file sees what the brew was before the wall of numbers.
  @Test("The readings come last")
  func samplesLast() throws {
    let samples = try #require(json.range(of: "\"samples\""))
    for name in ["brewed", "recipe", "dose", "grinder", "beakerB"] {
      #expect(try #require(json.range(of: "\"\(name)\"")?.lowerBound) < samples.lowerBound)
    }
  }

  /// The filename is the brew's name, and whether it finished is a fact
  /// about the brew rather than about the readings.
  @Test("The sidecar leaves out what it would be repeating")
  func leavesOutTheDuplicates() {
    var early = record
    early.finished = false

    #expect(!json.contains("\"brew\":"))
    #expect(!json.contains("finished"))
    #expect(!early.json(trace: PourTrace()).contains("finished"))
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

  /// Fifteen fields sit above the readings, and the reader walks past all of
  /// them to reach the ones it wants.
  @Test("The readings come back out from under the facts")
  func readsPastTheFacts() {
    var trace = PourTrace()
    trace.append(seconds: 0.1, grams: 0.4)
    trace.append(seconds: 0.2, grams: 1.1)

    let parsed = PourTrace.parse(json: record.json(trace: trace))

    #expect(parsed?.samples.map(\.grams) == [0.4, 1.1])
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
