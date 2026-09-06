import DevilKit
import SwiftUI

/// What the scale reads, against what it ought to read.
///
/// The recipe knows the running total at every step, so the pair says when to
/// stop pouring rather than leaving that arithmetic to whoever is holding the
/// kettle. Green once the target is reached, which is the whole signal.
///
/// Readings arrive about ten times a second, measured on a Pearl S rather than
/// taken from the documentation, which claims five. Fast enough that the last
/// digit moves constantly while pouring, which is what the scale's own display
/// does too.
struct WeightReadout: View {
  let grams: Double?
  let target: Double
  /// Grams a second, or `nil` before there are enough readings to say.
  let flow: Double?

  /// Reserved on both sides of the weight, so the figure everyone actually
  /// reads stays centred and does not slide sideways when the rate appears.
  @ScaledMetric private var rateWidth: Double = 74

  private var reached: Bool {
    (grams ?? 0) >= target
  }

  private var fraction: Double {
    guard target > 0 else { return 0 }
    return min(1, max(0, (grams ?? 0) / target))
  }

  var body: some View {
    VStack(spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Color.clear.frame(width: rateWidth, height: 0)
        Text(grams.map { Format.grams($0) } ?? "—")
          .font(.system(size: 44, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())
          .foregroundStyle(reached ? Color.green : .primary)
        Text(flow.map { Format.flow($0) } ?? "")
          .font(.subheadline)
          .monospacedDigit()
          .foregroundStyle(.secondary)
          .frame(width: rateWidth, alignment: .leading)
      }
      HStack(spacing: 8) {
        ProgressView(value: fraction)
          .tint(reached ? .green : .accentColor)
        Text("of \(Format.grams(target))")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .monospacedDigit()
          .fixedSize()
      }
    }
    .padding(.top, 8)
    .animation(.snappy, value: reached)
  }
}
