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
    trace.drawableSegments(limit: Self.drawnPoints)
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
    // Every step is a rule, but only a few are labelled. Labelling all of them
    // ran `0:00` into `0:10`, and two steps ten seconds apart cannot both be
    // named on a phone. The rules already mark where the steps are.
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) { value in
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
    .frame(height: 110)
    .padding(.bottom)
  }
}
