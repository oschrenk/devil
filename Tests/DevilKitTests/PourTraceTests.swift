@testable import DevilKit
import Testing

@Suite("Pour trace")
struct PourTraceTests {
  @Test("Readings that go backwards in time are dropped")
  func monotonic() {
    var trace = PourTrace()
    trace.append(seconds: 1, grams: 10)
    trace.append(seconds: 0.5, grams: 20)
    trace.append(seconds: 1, grams: 30)
    trace.append(seconds: 2, grams: 40)

    #expect(trace.samples.map(\.seconds) == [1, 2])
  }

  /// Ten grams over two seconds is five grams a second, and the arithmetic
  /// should say so without a window quietly changing the answer.
  @Test("The flow rate matches the arithmetic by hand")
  func flowRate() throws {
    var trace = PourTrace()
    for step in 0 ... 20 {
      let seconds = Double(step) / 10
      trace.append(seconds: seconds, grams: seconds * 5)
    }

    #expect(try abs(#require(trace.flow(at: 2, window: 2)) - 5) < 0.001)
  }

  @Test("A flat stretch has no flow")
  func noFlow() {
    var trace = PourTrace()
    for step in 0 ... 10 {
      trace.append(seconds: Double(step) / 10, grams: 50)
    }

    #expect(trace.flow(at: 1, window: 1) == 0)
  }

  @Test("A rate cannot be taken from a window holding one reading")
  func tooFewSamples() {
    var trace = PourTrace()
    trace.append(seconds: 10, grams: 50)

    #expect(trace.flow(at: 10, window: 0.5) == nil)
    #expect(PourTrace().flow(at: 0) == nil)
  }

  /// A dropped scale leaves a hole, and a line across it claims a steady pour
  /// that never happened.
  @Test("A gap splits the trace rather than joining across it")
  func gapsSplit() {
    var trace = PourTrace()
    for step in 0 ... 5 {
      trace.append(seconds: Double(step) / 10, grams: 10)
    }
    for step in 0 ... 5 {
      trace.append(seconds: 30 + Double(step) / 10, grams: 80)
    }

    let segments = trace.segments()

    #expect(segments.count == 2)
    #expect(segments[0].count == 6)
    #expect(segments[1].count == 6)
  }

  @Test("An unbroken trace is one segment, and an empty one is none")
  func continuous() {
    var trace = PourTrace()
    for step in 0 ... 30 {
      trace.append(seconds: Double(step) / 10, grams: Double(step))
    }

    #expect(trace.segments().count == 1)
    #expect(PourTrace().segments().isEmpty)
  }

  /// A whole brew at the rate the scale actually reports.
  @Test("A brew's worth of readings stays one segment")
  func aWholeBrew() {
    var trace = PourTrace()
    for tick in 0 ... 1950 {
      let seconds = Double(tick) / 10
      trace.append(seconds: seconds, grams: min(250, seconds * 1.3))
    }

    #expect(trace.samples.count == 1951)
    #expect(trace.segments().count == 1)
    #expect(trace.samples.last?.grams == 250)
  }

  @Test("Bucketing for the chart does not invent gaps")
  func drawableKeepsOneSegment() {
    var trace = PourTrace()
    for tick in 0 ... 1950 {
      trace.append(seconds: Double(tick) / 10, grams: Double(tick) / 10)
    }

    let drawn = trace.drawableSegments(limit: 200)

    #expect(drawn.count == 1)
    #expect(drawn[0].count <= 200)
    #expect(drawn[0].count > 150)
  }

  @Test("Bucketing for the chart keeps a real gap")
  func drawableKeepsGaps() {
    var trace = PourTrace()
    for tick in 0 ... 600 {
      trace.append(seconds: Double(tick) / 10, grams: 10)
    }
    for tick in 0 ... 600 {
      trace.append(seconds: 120 + Double(tick) / 10, grams: 200)
    }

    let drawn = trace.drawableSegments(limit: 100)

    #expect(drawn.count == 2)
    #expect(drawn.allSatisfy { $0.count >= 2 })
    #expect(drawn.flatMap(\.self).count <= 110)
  }

  @Test("A short trace is drawn whole")
  func drawableShortTrace() {
    var trace = PourTrace()
    for tick in 0 ... 20 {
      trace.append(seconds: Double(tick), grams: Double(tick))
    }

    #expect(trace.drawableSegments(limit: 200) == trace.segments())
  }

  /// Lifting the server off the scale reads well below zero.
  @Test("A reading below the frame is held at the floor, not dropped")
  func clampsBelow() {
    var trace = PourTrace()
    trace.append(seconds: 1, grams: 50)
    trace.append(seconds: 2, grams: -32.5)
    trace.append(seconds: 3, grams: 0)

    let drawn = trace.drawableSegments(limit: 200, within: 0 ... 250).flatMap(\.self)

    #expect(drawn.map(\.grams) == [50, 0, 0])
    #expect(drawn.map(\.seconds) == [1, 2, 3])
  }

  @Test("A reading above the frame is held at the ceiling")
  func clampsAbove() {
    var trace = PourTrace()
    trace.append(seconds: 1, grams: 240)
    trace.append(seconds: 2, grams: 310)

    let drawn = trace.drawableSegments(limit: 200, within: 0 ... 250).flatMap(\.self)

    #expect(drawn.map(\.grams) == [240, 250])
  }

  @Test("Without a range the readings are drawn as they came")
  func noClamping() {
    var trace = PourTrace()
    trace.append(seconds: 1, grams: -5)
    trace.append(seconds: 2, grams: 400)

    #expect(trace.drawableSegments(limit: 200).flatMap(\.self).map(\.grams) == [-5, 400])
  }

  /// Clamping runs after thinning, so it must not disturb either the gaps or
  /// the number of points that survived.
  @Test("Clamping leaves the shape of a bucketed trace alone")
  func clampingKeepsShape() {
    var trace = PourTrace()
    for tick in 0 ... 600 {
      trace.append(seconds: Double(tick) / 10, grams: -50)
    }
    for tick in 0 ... 600 {
      trace.append(seconds: 120 + Double(tick) / 10, grams: 500)
    }

    let plain = trace.drawableSegments(limit: 100)
    let clamped = trace.drawableSegments(limit: 100, within: 0 ... 250)

    #expect(clamped.count == plain.count)
    #expect(clamped.map(\.count) == plain.map(\.count))
    #expect(clamped.flatMap(\.self).map(\.seconds) == plain.flatMap(\.self).map(\.seconds))
    #expect(Set(clamped.flatMap(\.self).map(\.grams)) == [0, 250])
  }

  /// The spikes on the graph were single bad readings from the scale, drawn
  /// as a vertical line to nowhere and back.
  @Test("A lone bad reading is outvoted by its neighbours")
  func spikesAreVotedOut() {
    var trace = PourTrace()
    for tick in 0 ... 300 {
      trace.append(seconds: Double(tick) / 10, grams: tick == 150 ? 9999 : 100)
    }

    let drawn = trace.drawableSegments(limit: 200).flatMap(\.self)

    #expect(!drawn.isEmpty)
    #expect(drawn.allSatisfy { $0.grams == 100 })
  }

  /// Why the buckets are cut by time. A point once drawn has to stay where it
  /// is as the brew goes on, or the whole line re-picks itself every second
  /// and a bad reading blinks in and out as the spacing slides over it.
  @Test("Points already drawn do not move as more readings arrive")
  func stableUnderGrowth() {
    var early = PourTrace()
    for tick in 0 ... 1000 {
      early.append(seconds: Double(tick) / 10, grams: Double(tick) / 10)
    }
    var later = early
    for tick in 1001 ... 1500 {
      later.append(seconds: Double(tick) / 10, grams: Double(tick) / 10)
    }

    let before = early.drawableSegments(limit: 200).flatMap(\.self)
    let after = later.drawableSegments(limit: 200).flatMap(\.self)

    // All but the last, which sits in a bucket that was still filling.
    #expect(before.count > 90)
    #expect(after.count > before.count)
    #expect(before.dropLast() == Array(after.prefix(before.count - 1)))
  }

  /// A rate read from single endpoints is wrong by the whole of a bad reading
  /// that lands on one.
  @Test("A bad reading at the edge of the window does not wreck the rate")
  func flowIgnoresSpike() throws {
    var trace = PourTrace()
    for tick in 0 ... 20 {
      let seconds = Double(tick) / 10
      trace.append(seconds: seconds, grams: tick == 20 ? 9999 : seconds * 5)
    }

    #expect(try abs(#require(trace.flow(at: 2, window: 2)) - 5) < 0.5)
  }

  @Test("A bucket is a whole number of seconds wide, and never narrower than one")
  func bucketWidth() {
    #expect(PourTrace.bucketWidth(span: 195, limit: 200) == 1)
    #expect(PourTrace.bucketWidth(span: 20, limit: 200) == 1)
    #expect(PourTrace.bucketWidth(span: 400, limit: 200) == 2)
    #expect(PourTrace.bucketWidth(span: 0, limit: 200) == 1)
  }
}
