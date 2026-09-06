import DevilKit
import SwiftUI

/// The running brew.
///
/// The clock free-runs from a start date rather than waiting for a tap at each
/// step. The recipe is timed against the wall, not against how fast you pour:
/// the cold add at 1:45 works because the kettle has been cooling for exactly
/// that long. Tap-to-advance would let the whole brew drift late and quietly
/// change the temperature the recipe is built on.
struct TimerView: View {
  let recipe: Recipe
  let brew: RunningBrew

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    // Ticks from the press, not from 0:00, so the lead-in counts down too.
    TimelineView(.periodic(from: brew.tappedAt, by: 1)) { context in
      let untilStart = brew.start.timeIntervalSince(context.date)
      let countdown = Countdown.remaining(untilStart: untilStart)
      let elapsed = max(0, Int(-untilStart.rounded(.up)))
      let progress = recipe.progress(atSeconds: elapsed)

      VStack(spacing: 0) {
        Clock(progress: progress, countdown: countdown)
        CurrentStep(recipe: recipe, progress: progress)
        Spacer(minLength: 0)
        Schedule(recipe: recipe, progress: progress)
      }
      .padding(.horizontal)
      .animation(.snappy, value: progress.stepIndex)
    }
    .navigationTitle("Brewing")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Stop", role: .destructive) { dismiss() }
      }
    }
    // A brew is followed with the phone on the counter and wet hands. Nothing
    // touches the screen for three minutes, so stop it going dark.
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
  }
}

/// The clock, counting down to 0:00 and then up.
///
/// Red while it counts down, because that is the only time the number means
/// "not yet" rather than "how long it has been". The two run in the same
/// m:ss shape so the digits do not jump when it turns over.
private struct Clock: View {
  let progress: BrewProgress
  let countdown: Int

  private var isCountingDown: Bool {
    countdown > 0
  }

  private var shown: BrewTime {
    isCountingDown ? BrewTime(seconds: countdown) : progress.elapsed
  }

  var body: some View {
    VStack(spacing: 4) {
      Text(shown.formatted)
        .font(.system(size: 68, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
        .foregroundStyle(isCountingDown ? .red : .primary)
      ProgressView(value: isCountingDown ? 0 : progress.fraction)
        .tint(progress.isComplete ? .green : .accentColor)
    }
    .padding(.vertical, 8)
  }
}

/// What to do now, large enough to read from across the counter.
private struct CurrentStep: View {
  let recipe: Recipe
  let progress: BrewProgress

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(progress.step.title)
          .font(.title2.weight(.semibold))
        Spacer()
        SwitchBadge(position: progress.step.switchPosition)
      }

      ForEach(recipe.instructions(for: progress.step), id: \.self) { line in
        InstructionRow(text: line)
      }

      if let seconds = progress.secondsUntilNextStep, let next = progress.nextStep {
        Text("\(next.title) in \(seconds)s")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 16))
  }
}

/// The switch position is the one thing that ruins a brew rather than delaying
/// it, so it gets colour and a shape rather than a line of text.
private struct SwitchBadge: View {
  let position: SwitchPosition

  var body: some View {
    Label(
      position == .open ? "Open" : "Closed",
      systemImage: position == .open ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    )
    .font(.headline)
    .foregroundStyle(position == .open ? .green : .orange)
  }
}

private struct Schedule: View {
  let recipe: Recipe
  let progress: BrewProgress

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(recipe.steps.enumerated()), id: \.element.start) { index, step in
        HStack {
          Text(step.start.formatted)
            .monospacedDigit()
            .frame(width: 46, alignment: .leading)
          Text(step.title)
          Spacer()
          if step.poured > 0 {
            Text(Format.grams(step.poured))
          }
        }
        .font(.subheadline)
        .foregroundStyle(index == progress.stepIndex ? .primary : .tertiary)
        .fontWeight(index == progress.stepIndex ? .semibold : .regular)
        .padding(.vertical, 6)
      }
    }
    .padding(.bottom)
  }
}

/// One line of what to do.
///
/// The bullet is a `Text`, not an SF Symbol. `.firstTextBaseline` puts an
/// image's bottom edge on the baseline, so a small dot sits low against the
/// words. A glyph carries the font's own metrics and lines up on its own.
private struct InstructionRow: View {
  let text: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text("\u{2022}")
        .foregroundStyle(.secondary)
        .frame(width: 10, alignment: .leading)
      Text(text)
    }
    .font(.title3)
  }
}

#Preview {
  NavigationStack {
    TimerView(recipe: .switchWaterAndTempManaged, brew: RunningBrew(tappedAt: .now))
  }
}
