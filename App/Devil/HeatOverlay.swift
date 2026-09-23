import DevilKit
import SwiftUI

/// Putting degrees on a chart that measures grams.
///
/// Swift Charts gives a plot one Y scale, so a second series in another unit
/// has to be projected onto the first and labelled back on the trailing edge.
/// That is what this does, and the arithmetic lives here rather than inside
/// two charts that would each get it slightly wrong.
///
/// The range comes from the readings rather than from a fixed span. A brew
/// moves through maybe twenty degrees, and a 0 to 100 axis would draw that as
/// a flat line.
struct HeatOverlay {
  let trace: HeatTrace
  /// Which of the five to draw. Zone one until a brew says otherwise, which
  /// needs the probe in a bed rather than a mug.
  let zone: Int
  /// The weight domain this is being projected into.
  let ceiling: Double

  var isEmpty: Bool {
    samples.isEmpty
  }

  var samples: [PourSample] {
    trace.zone(zone)
  }

  /// Padded, so the warmest reading is not drawn on the frame itself.
  var range: ClosedRange<Double> {
    guard let found = trace.range else { return 0 ... 1 }
    let margin = max(1, (found.upperBound - found.lowerBound) * 0.1)
    return (found.lowerBound - margin) ... (found.upperBound + margin)
  }

  /// A temperature, as a height in the weight domain.
  func projected(_ celsius: Double) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else { return 0 }
    return (celsius - range.lowerBound) / span * ceiling
  }

  /// And back, for the trailing axis labels.
  func celsius(atHeight height: Double) -> Double {
    guard ceiling > 0 else { return range.lowerBound }
    return range.lowerBound + height / ceiling * (range.upperBound - range.lowerBound)
  }

  /// Four labels. More crowds the edge of a graph this small.
  var marks: [Double] {
    (0 ... 4).map { Double($0) / 4 * ceiling }
  }
}
