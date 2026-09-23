import Charts
import DevilKit
import SwiftUI

/// The pour, read afterwards rather than during.
///
/// This one scrolls and pinches, where the timer's does neither. A running
/// brew wants a shape that holds still in one frame and answers whether the
/// pour is ahead or behind. Reading a brew back wants the detail, and by then
/// there are two hands.
struct BrewGraph: View {
  let trace: PourTrace
  /// The pour the recipe intended, for this brew's size.
  let ideal: [PourSample]
  let total: Double
  let ceiling: Double
  /// Empty for a brew made without a probe, and then nothing below draws.
  var heat = HeatTrace()
  var zone = 0

  /// Seconds across the screen. The whole brew to start with, so the first
  /// look is the same shape the timer showed.
  @State private var window: Double?
  @GestureState private var pinch: Double = 1

  private var visible: Double {
    min(total, max(10, (window ?? total) / pinch))
  }

  private var drawn: [[PourSample]] {
    // More points than the timer draws, because a pinched-in view is asking
    // for exactly the detail the timer had no room for.
    trace.drawableSegments(limit: 600, within: 0 ... ceiling)
  }

  private var overlay: HeatOverlay {
    HeatOverlay(trace: heat, zone: zone, ceiling: ceiling)
  }

  var body: some View {
    Chart {
      ForEach(overlay.samples) { point in
        LineMark(
          x: .value("Time", point.seconds),
          y: .value("Weight", overlay.projected(point.grams)),
          series: .value("Pour", "heat")
        )
        .foregroundStyle(.orange)
        .lineStyle(StrokeStyle(lineWidth: 1.5))
      }
      // The pour the recipe intends, under the one you are making. Drawn
      // first so a real pour sits on top of it rather than behind it.
      ForEach(ideal) { point in
        LineMark(
          x: .value("Time", point.seconds),
          y: .value("Weight", point.grams),
          series: .value("Pour", "ideal")
        )
        .foregroundStyle(.red.opacity(0.55))
        .lineStyle(StrokeStyle(lineWidth: 1.5))
      }
      ForEach(drawn.indices, id: \.self) { index in
        ForEach(drawn[index]) { sample in
          LineMark(
            x: .value("Time", sample.seconds),
            y: .value("Weight", sample.grams),
            series: .value("Pour", "actual \(index)")
          )
        }
      }
    }
    .chartXScale(domain: 0 ... total)
    .chartYScale(domain: 0 ... ceiling)
    .chartYAxis {
      AxisMarks(values: .stride(by: 100)) { AxisGridLine() }
      if !overlay.isEmpty {
        AxisMarks(position: .trailing, values: overlay.marks) { value in
          AxisValueLabel(
            Format.degrees(overlay.celsius(atHeight: value.as(Double.self) ?? 0))
          )
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .stride(by: 30)) { value in
        AxisGridLine()
        AxisValueLabel(BrewTime(seconds: Int(value.as(Double.self) ?? 0)).formatted)
      }
    }
    .chartScrollableAxes(.horizontal)
    .chartXVisibleDomain(length: visible)
    .frame(height: 200)
    .gesture(
      MagnifyGesture()
        .updating($pinch) { value, state, _ in state = value.magnification }
        .onEnded { value in window = min(total, max(10, visible / value.magnification)) }
    )
  }
}
