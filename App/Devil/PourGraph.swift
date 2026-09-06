import Charts
import DevilKit
import SwiftUI

/// The pour so far, weight against the clock.
///
/// Drawn against the whole brew rather than against what has happened, so the
/// line grows into a fixed frame. An axis that rescales every second makes two
/// brews impossible to compare and hides whether a pour is early or late.
struct PourGraph: View {
  let recipe: Recipe
  let trace: PourTrace

  /// About one point per two screen points across the width of a phone. Beyond
  /// that the extra readings land on pixels already drawn, and redrawing them
  /// ten times a second costs frames for a line nobody can see.
  private static let drawnPoints = 200

  private var drawn: [[PourSample]] {
    // Held inside the frame. Lifting the server reads well below zero, and a
    // line that leaves the box draws over the rest of the screen.
    trace.drawableSegments(limit: Self.drawnPoints, within: 0 ... recipe.waterThroughBed)
  }

  var body: some View {
    Chart {
      ForEach(recipe.steps, id: \.start) { step in
        RuleMark(x: .value("Time", Double(step.start.seconds)))
          .foregroundStyle(.quaternary)
          .lineStyle(StrokeStyle(lineWidth: 1))
      }
      ForEach(drawn.indices, id: \.self) { index in
        ForEach(drawn[index]) { sample in
          LineMark(
            x: .value("Time", sample.seconds),
            y: .value("Weight", sample.grams),
            // Each stretch is its own series, so a scale that dropped out
            // draws as the hole it was rather than as a steady pour across it.
            series: .value("Pour", index)
          )
        }
      }
    }
    .chartXScale(domain: 0 ... Double(recipe.totalTime.seconds))
    .chartYScale(domain: 0 ... recipe.waterThroughBed)
    .chartYAxis(.hidden)
    // The recipe's own times, not an even stride. `0:45` and `1:45` are when
    // something happens; `0:50` and `1:40` are arithmetic, and reading the
    // graph against them means doing that arithmetic in your head.
    //
    // Every step is ruled, but only the ones far enough apart are named:
    // labelling all seven ran `0:00` into `0:10`.
    .chartXAxis {
      AxisMarks(values: recipe.labelledStepTimes(minimumGap: 25).map(Double.init)) { value in
        AxisValueLabel {
          if let seconds = value.as(Double.self) {
            Text(BrewTime(seconds: Int(seconds)).formatted)
              .font(.caption2)
              .monospacedDigit()
          }
        }
      }
    }
    .chartLegend(.hidden)
    // Grows into whatever the step card leaves, up to a point. Collapsing the
    // card should buy a taller graph, not hand the graph the whole screen: at
    // full height it dominates a view whose subject is the clock.
    .frame(minHeight: 110, maxHeight: 200)
    .padding(.top, 14)
    .padding(.bottom)
  }
}
