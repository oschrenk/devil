@testable import DevilKit
import Testing

@Suite("Heat trace")
struct HeatTraceTests {
  private func trace() -> HeatTrace {
    var heat = HeatTrace()
    heat.append(seconds: 12.4, zones: [78.1, 79, 79.2, 80.1, 80.4], ambient: 24.9)
    heat.append(seconds: 14.55, zones: [79.4, 80, 80.2, 81.1, 81.4], ambient: 25)
    return heat
  }

  /// The sidecar is the record, so a series that cannot be read back is a
  /// series nobody can check.
  @Test("A series survives the trip to JSON and back")
  func roundTrip() {
    let original = trace()
    #expect(HeatTrace.parse(json: original.samplesJSON) == original)
  }

  /// Seconds to hundredths, degrees to tenths. The probe reports tenths, so a
  /// second decimal on a temperature would be invented precision.
  @Test("Seconds keep hundredths and degrees keep tenths")
  func precision() {
    let json = trace().samplesJSON
    #expect(json.contains("[12.4, 78.1, 79, 79.2, 80.1, 80.4, 24.9]"))
    #expect(json.contains("14.55"))
  }

  /// A reading that arrives late would draw the curve backwards.
  @Test("Readings out of order are dropped")
  func ordering() {
    var heat = trace()
    heat.append(seconds: 1, zones: [10, 10, 10, 10, 10], ambient: 10)
    #expect(heat.samples.count == 2)
    // And a reading with no zones is not a reading.
    heat.append(seconds: 99, zones: [], ambient: 20)
    #expect(heat.samples.count == 2)
  }

  /// One zone, for drawing. A zone that does not exist gives nothing rather
  /// than a line with holes in it.
  @Test("A zone draws as a series, and an absent one draws as nothing")
  func zones() {
    #expect(trace().zone(0).map(\.grams) == [78.1, 79.4])
    #expect(trace().zone(4).map(\.grams) == [80.4, 81.4])
    #expect(trace().zone(5).isEmpty)
    #expect(trace().zone(-1).isEmpty)
  }

  /// The chart axis wants the span of everything, not of one zone.
  @Test("The range covers every zone")
  func range() {
    let found = trace().range
    #expect(found?.lowerBound == 78.1)
    #expect(found?.upperBound == 81.4)
    #expect(HeatTrace().range == nil)
  }

  @Test("A sidecar's temperatures are found among its samples")
  func extraction() {
    let json = "{\"dose\": 15, \"samples\": [[0, 0], [1, 5]], "
      + "\"temperatures\": \(trace().samplesJSON)}"
    let body = HeatTrace.body(in: json)
    #expect(body != nil)
    #expect(HeatTrace.parse(json: body ?? "") == trace())
    // A brew with no probe has no such key.
    #expect(HeatTrace.body(in: "{\"samples\": [[0, 0]]}") == nil)
  }
}

@Suite("Heat in the sidecar")
struct HeatSidecarTests {
  private var stamp: BrewStamp {
    BrewStamp(year: 2026, month: 9, day: 23, hour: 7, minute: 14)
  }

  private func record() -> BrewRecord {
    BrewRecord.of(settings: BrewSettings(servings: 1), at: stamp, finished: true)
  }

  /// A brew with no probe writes no key, rather than an empty array. An empty
  /// array claims a probe was watching and saw nothing.
  @Test("No probe writes no temperatures at all")
  func absent() {
    #expect(!record().json(trace: PourTrace()).contains("temperatures"))
    #expect(!record().json(trace: PourTrace(), heat: HeatTrace()).contains("temperatures"))
  }

  @Test("A probe's readings follow the samples")
  func present() {
    var heat = HeatTrace()
    heat.append(seconds: 30, zones: [90.5, 91, 91.2, 88, 60.4], ambient: 26.1)
    let json = record().json(trace: PourTrace(), heat: heat)
    #expect(json.contains("\"temperatures\": [[30, 90.5, 91, 91.2, 88, 60.4, 26.1]]"))
    // After the samples, for the reason the samples go last.
    let samples = json.range(of: "\"samples\"")
    let temperatures = json.range(of: "\"temperatures\"")
    #expect(samples != nil)
    #expect(temperatures != nil)
    if let samples, let temperatures {
      #expect(samples.lowerBound < temperatures.lowerBound)
    }
  }
}
