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
  let total: Double
  let ceiling: Double

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

  var body: some View {
    Chart {
      ForEach(drawn.indices, id: \.self) { index in
        ForEach(drawn[index]) { sample in
          LineMark(
            x: .value("Time", sample.seconds),
            y: .value("Weight", sample.grams),
            series: .value("Pour", index)
          )
        }
      }
    }
    .chartXScale(domain: 0 ... total)
    .chartYScale(domain: 0 ... ceiling)
    .chartYAxis {
      AxisMarks(values: .stride(by: 100)) { AxisGridLine() }
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
