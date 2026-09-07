@testable import DevilKit
import Testing

@Suite("Pour trace JSON")
struct PourTraceJSONTests {
  /// A sidecar for a trace, so these stay about the readings. The facts
  /// written beside them are `BrewRecordJSONTests`.
  private func json(_ trace: PourTrace) -> String {
    BrewRecord.of(
      settings: BrewSettings(),
      at: BrewStamp(year: 2026, month: 9, day: 6, hour: 7, minute: 14),
      finished: true
    )
    .json(trace: trace)
  }

  /// Built at the resolution the file stores: hundredths of a second, and the
  /// tenth of a gram the scale reports.
  private func trace(count: Int) -> PourTrace {
    var trace = PourTrace()
    for tick in 0 ..< count {
      let seconds = (Double(tick) / 10 * 100).rounded() / 100
      trace.append(seconds: seconds, grams: (min(250, seconds * 1.3) * 10).rounded() / 10)
    }
    return trace
  }

  @Test("A trace survives the trip to JSON and back")
  func roundTrip() {
    let original = trace(count: 40)

    let parsed = PourTrace.parse(json: json(original))
    #expect(parsed?.samples == original.samples)
  }

  @Test("A brew with no readings writes an empty list")
  func emptyTrace() {
    let json = json(PourTrace())

    #expect(json.contains("\"samples\": []"))
    #expect(PourTrace.parse(json: json)?.samples.isEmpty == true)
  }

  /// Pairs rather than objects, because a brew is two thousand readings.
  @Test("A whole brew stays under forty kilobytes")
  func size() {
    let json = json(trace(count: 2000))

    #expect(json.utf8.count < 40000)
    #expect(json.utf8.count > 10000)
  }

  @Test("A reading that goes backwards is dropped on the way in")
  func dropsBackwards() {
    let json = "{\"brew\": \"b\", \"samples\": [[1, 10], [0.5, 20], [2, 30]]}"

    let parsed = PourTrace.parse(json: json)

    #expect(parsed?.samples.map(\.seconds) == [1, 2])
  }

  @Test("Whitespace between the numbers makes no difference")
  func tolerantOfSpacing() {
    let json = "{\"brew\": \"b\",\n  \"samples\": [\n    [0.1, 0.4],\n    [0.2, 1.1]\n  ]\n}"

    #expect(PourTrace.parse(json: json)?.samples.count == 2)
  }

  /// A half-written file must not throw its way into the app.
  @Test("Rubbish parses to nothing")
  func rejectsRubbish() {
    #expect(PourTrace.parse(json: "") == nil)
    #expect(PourTrace.parse(json: "{}") == nil)
    #expect(PourTrace.parse(json: "not json at all") == nil)
    #expect(PourTrace.parse(json: "{\"brew\": \"b\"}") == nil)
    #expect(PourTrace.parse(json: "{\"brew\": \"b\", \"samples\": [[1, 2, 3]]}") == nil)
    #expect(PourTrace.parse(json: "{\"brew\": \"b\", \"samples\": [[1]]}") == nil)
    #expect(PourTrace.parse(json: "{\"brew\": \"b\", \"samples\": [[1, x]]}") == nil)
  }

  /// The file stores hundredths of a second, so a clock difference carrying
  /// more than that arrives back rounded. Ten milliseconds is far inside what
  /// a flow rate or a graph can use.
  @Test("A reading finer than a hundredth comes back rounded to one")
  func roundsFinePrecision() {
    var original = PourTrace()
    original.append(seconds: 12.417293834, grams: 102.4)

    let parsed = PourTrace.parse(json: json(original))

    #expect(parsed?.samples.first?.seconds == 12.42)
    #expect(parsed?.samples.first?.grams == 102.4)
  }

  @Test("A reading keeps the one decimal the scale reports")
  func precision() {
    var original = PourTrace()
    original.append(seconds: 12.3, grams: 102.4)
    original.append(seconds: 12.4, grams: -3.5)

    let parsed = PourTrace.parse(json: json(original))

    #expect(parsed?.samples == original.samples)
    #expect(json(original).contains("[12.3, 102.4]"))
    #expect(json(original).contains("[12.4, -3.5]"))
  }

  /// What too much precision costs.
  ///
  /// Two readings inside the same hundredth round to one instant, and the
  /// second is not later than the first any more, so `append` drops it as a
  /// reading that went backwards. The scale reports about ten times a second,
  /// which leaves ten hundredths between readings, so this needs the scale to
  /// speed up tenfold before it can happen.
  @Test("Readings inside the same hundredth collapse to the first")
  func collidingReadings() {
    var original = PourTrace()
    original.append(seconds: 1.234, grams: 10)
    original.append(seconds: 1.236, grams: 20)
    original.append(seconds: 1.244, grams: 30)

    let parsed = PourTrace.parse(json: json(original))

    // 1.236 rounds up to 1.24, so 1.244 is the one that collides and goes.
    #expect(original.samples.count == 3)
    #expect(parsed?.samples.map(\.seconds) == [1.23, 1.24])
    #expect(parsed?.samples.map(\.grams) == [10, 20])
  }

  /// A tenth of a gram is what the scale resolves, so nothing finer is real.
  @Test("A weight finer than a tenth rounds to one")
  func gramsRoundToATenth() {
    var original = PourTrace()
    original.append(seconds: 1, grams: 102.44)
    original.append(seconds: 2, grams: 102.46)

    let parsed = PourTrace.parse(json: json(original))

    #expect(parsed?.samples.map(\.grams) == [102.4, 102.5])
  }
}
