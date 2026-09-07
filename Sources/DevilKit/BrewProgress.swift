/// Where the brew is, at one moment on the clock.
///
/// A value rather than a running object: nothing here ticks. Hand it a number
/// of seconds and it says what to do, which is what makes the whole schedule
/// testable without waiting three minutes.
public struct BrewProgress: Equatable, Sendable {
  public let elapsed: BrewTime
  /// Where `step` sits in `Recipe.steps`.
  public let stepIndex: Int
  public let step: Step
  public let nextStep: Step?
  public let secondsIntoStep: Int
  /// Counts down to the next step, or `nil` on the last one.
  public let secondsUntilNextStep: Int?
  /// The brew has reached the end of its schedule.
  public let isComplete: Bool

  /// How far through the whole schedule, from 0 to 1.
  public let fraction: Double
}

public extension Recipe {
  /// What to do at `seconds` on the brew clock.
  ///
  /// Before 0:00 it reports the first step, so a screen has something to show
  /// while the kettle is still coming up. Past the end it holds on the last
  /// step and sets `isComplete`.
  func progress(atSeconds seconds: Int) -> BrewProgress {
    let clock = max(0, seconds)
    let ordered = steps.sorted { $0.start < $1.start }
    let index = ordered.lastIndex { $0.start.seconds <= clock } ?? 0
    let step = ordered[index]
    let next = index + 1 < ordered.count ? ordered[index + 1] : nil
    let total = totalTime.seconds

    return BrewProgress(
      elapsed: BrewTime(seconds: clock),
      stepIndex: index,
      step: step,
      nextStep: next,
      secondsIntoStep: clock - step.start.seconds,
      secondsUntilNextStep: next.map { $0.start.seconds - clock },
      isComplete: clock >= total,
      fraction: total == 0 ? 1 : min(1, Double(clock) / Double(total))
    )
  }

  /// What to do at this step, in the order to do it.
  ///
  /// The switch line comes first and only when the position changes, because
  /// the recipe is explicit that the valve moves before the water does. A
  /// pour into an open switch that should have been closed is a different
  /// brew, not a late one.
  func instructions(for step: Step) -> [String] {
    let ordered = steps.sorted { $0.start < $1.start }
    guard let index = ordered.firstIndex(of: step) else { return [] }
    let previous = index > 0 ? ordered[index - 1].switchPosition : nil

    var lines: [String] = []
    if previous != step.switchPosition {
      lines.append(step.switchPosition == .open ? "Open the switch" : "Close the switch")
    }
    for action in step.actions {
      switch action {
      case let .pour(grams):
        // The seconds and the rate, because a pour is paced rather than
        // tipped. The weight alone says when to stop and nothing about how
        // fast to get there, and the rate is what the readout below counts
        // up against while you pour.
        if step.pourSeconds > 0 {
          let over = Int(step.pourSeconds.rounded())
          let rate = Format.flow(grams / step.pourSeconds)
          lines.append("Pour \(Format.grams(grams)) over \(over)s, \(rate)")
        } else {
          lines.append("Pour \(Format.grams(grams))")
        }
      case let .addCooler(grams):
        lines.append("Add \(Format.grams(grams)) cold water to the kettle")
      case .swirl:
        lines.append("Swirl")
      case .drain:
        lines.append("Let it drain")
      case .finish:
        lines.append("Pour and drink")
      }
    }
    return lines
  }
}
