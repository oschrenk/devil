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
      // The recipe's phases, dashed so they cannot be mistaken for the time
      // scale. Solid and unnumbered they read as ticks whose labels went
      // missing, which is exactly how they were read.
      ForEach(recipe.steps, id: \.start) { step in
        RuleMark(x: .value("Time", Double(step.start.seconds)))
          .foregroundStyle(.quaternary)
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
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
    // A line every hundred grams, unnumbered. The weight is already read off
    // the figure above; these are here to judge a slope against.
    .chartYAxis {
      AxisMarks(values: .stride(by: 100)) {
        AxisGridLine()
      }
    }
    // The recipe's own times, not an even stride. `1:45` is when something
    // happens; `1:40` is arithmetic, and reading the graph against it means
    // doing that arithmetic in your head.
    // The rule and its number are drawn by the same axis, not by a `RuleMark`
    // placed alongside it. Drawn separately they came out sixteen points
    // apart, because a mark is positioned in the plot and a label is not.
    // A steady half minute, which is a scale you can read a slope against.
    // The recipe's own times were tried first and were worse: they are
    // unevenly spaced, so nothing about the axis was predictable.
    .chartXAxis {
      AxisMarks(values: .stride(by: 30)) { value in
        AxisGridLine()
        AxisValueLabel(BrewTime(seconds: Int(value.as(Double.self) ?? 0)).formatted, anchor: .top)
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
