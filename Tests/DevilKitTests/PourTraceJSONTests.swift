@testable import DevilKit
import Testing

@Suite("Pour trace JSON")
struct PourTraceJSONTests {
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

    let parsed = PourTrace.parse(json: original.json(brew: "2026-09-06-0714"))

    #expect(parsed?.brew == "2026-09-06-0714")
    #expect(parsed?.trace.samples == original.samples)
  }

  @Test("A brew with no readings writes an empty list")
  func emptyTrace() {
    let json = PourTrace().json(brew: "2026-09-06-0714")

    #expect(json == "{\"brew\": \"2026-09-06-0714\", \"samples\": []}")
    #expect(PourTrace.parse(json: json)?.trace.samples.isEmpty == true)
    #expect(PourTrace.parse(json: json)?.brew == "2026-09-06-0714")
  }

  /// Pairs rather than objects, because a brew is two thousand readings.
  @Test("A whole brew stays under forty kilobytes")
  func size() {
    let json = trace(count: 2000).json(brew: "2026-09-06-0714")

    #expect(json.utf8.count < 40000)
    #expect(json.utf8.count > 10000)
  }

  @Test("A reading that goes backwards is dropped on the way in")
  func dropsBackwards() {
    let json = "{\"brew\": \"b\", \"samples\": [[1, 10], [0.5, 20], [2, 30]]}"

    let parsed = PourTrace.parse(json: json)

    #expect(parsed?.trace.samples.map(\.seconds) == [1, 2])
  }

  @Test("Whitespace between the numbers makes no difference")
  func tolerantOfSpacing() {
    let json = "{\"brew\": \"b\",\n  \"samples\": [\n    [0.1, 0.4],\n    [0.2, 1.1]\n  ]\n}"

    #expect(PourTrace.parse(json: json)?.trace.samples.count == 2)
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

    let parsed = PourTrace.parse(json: original.json(brew: "b"))

    #expect(parsed?.trace.samples.first?.seconds == 12.42)
    #expect(parsed?.trace.samples.first?.grams == 102.4)
  }

  @Test("A reading keeps the one decimal the scale reports")
  func precision() {
    var original = PourTrace()
    original.append(seconds: 12.3, grams: 102.4)
    original.append(seconds: 12.4, grams: -3.5)

    let parsed = PourTrace.parse(json: original.json(brew: "b"))

    #expect(parsed?.trace.samples == original.samples)
    #expect(original.json(brew: "b").contains("[12.3, 102.4]"))
    #expect(original.json(brew: "b").contains("[12.4, -3.5]"))
  }
}
