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
  let scale: ScaleConnection

  @Environment(\.dismiss) private var dismiss
  @State private var clock = BrewClock()
  @State private var startSignal = BrewStartSignal()
  @State private var pausedBy = PauseSource.phone
  @State private var trace = PourTrace()
  /// What the chart draws, taken from `trace` once a second.
  ///
  /// The readings arrive ten times a second, but the line advances about two
  /// screen points in that time, so nine of every ten redraws produce pixels
  /// identical to the ones already there. Redrawing a few hundred marks for
  /// that is the most expensive thing on the screen and the least visible.
  @State private var drawnTrace = PourTrace()
  @State private var flow: Double?

  /// Reads the clock itself rather than borrowing the timeline's tick, which is
  /// what lets the toolbar live outside the per-second redraw.
  private func toggleHold() {
    let raw = Date.now.timeIntervalSince(brew.start)
    if clock.isHeld {
      clock.release(raw: raw)
      scale.send(.startTimer)
    } else {
      pausedBy = .phone
      clock.hold(raw: raw)
      scale.send(.stopTimer)
    }
  }

  /// Long enough to be silence rather than a gap between messages. The scale
  /// reports about every second once the subscription asks for one per
  /// heartbeat and the heartbeat runs at one, so this is three intervals.
  private static let scaleSilence: TimeInterval = 3

  var body: some View {
    // Ticks from the press, not from 0:00, so the lead-in counts down too, and
    // so the screen keeps redrawing while the clock is held.
    TimelineView(.periodic(from: brew.tappedAt, by: 1)) { context in
      let raw = context.date.timeIntervalSince(brew.start)
      let seconds = clock.elapsed(raw: raw)
      let countdown = Countdown.remaining(untilStart: -seconds)
      let progress = recipe.progress(atSeconds: max(0, Int(seconds.rounded(.down))))

      VStack(spacing: 0) {
        Clock(
          progress: progress,
          countdown: countdown,
          isHeld: clock.isHeld,
          hasScale: scale.state.isConnected
        )
        if clock.isHeld {
          HeldNote(source: pausedBy)
        } else {
          CurrentStep(recipe: recipe, progress: progress)
        }
        if scale.state.isConnected {
          WeightReadout(
            grams: scale.weight,
            target: recipe.cumulativeTarget(through: progress.step),
            flow: flow
          )
        }
        // The schedule is what you read before starting. Once the water is
        // going the step card already says what to do and when, so the space
        // is worth more as the shape of the pour you are actually making.
        //
        // The graph sits directly under the bar it belongs to. Pushed to the
        // foot of the screen it read as a separate panel, with the reading it
        // explains an inch away.
        if seconds > 0, !drawnTrace.samples.isEmpty {
          PourGraph(recipe: recipe, trace: drawnTrace)
          Spacer(minLength: 0)
        } else {
          Spacer(minLength: 0)
          Schedule(recipe: recipe, progress: progress)
        }
      }
      .padding(.horizontal)
      .animation(.snappy, value: progress.stepIndex)
      .animation(.snappy, value: clock.isHeld)
      // Both clocks then begin on the same instant, rather than moments apart
      // because two hands pressed two buttons.
      .onChange(of: Int(seconds.rounded(.down)), initial: true) { _, _ in
        for command in startSignal.commands(elapsed: seconds) {
          scale.send(command)
        }
      }
      // Keyed on the count of readings, not on the weight. A scale holding
      // steady between pours sends the same number ten times a second, and
      // `onChange` on the value sees none of them: the flat stretches went
      // unrecorded and the graph drew every one of them as a dropout.
      //
      // Each reading is kept. A Pearl S reports about ten times a second, so
      // a brew is roughly two thousand of them and thirty kilobytes, which is
      // small enough that thinning would trade real pour data for nothing.
      // The chart thins a copy; the flow rate and the log want all of it.
      //
      // Held readings are dropped rather than recorded flat. A pause is time
      // the brew did not spend, and writing it into the trace would flatten
      // the flow rate across a stretch where nothing was being poured.
      .onChange(of: scale.weightSamples) { _, _ in
        guard let grams = scale.weight, seconds > 0, !clock.isHeld else { return }
        let raw = Date.now.timeIntervalSince(brew.start)
        trace.append(seconds: clock.elapsed(raw: raw), grams: grams)
      }
      // Handing the chart a snapshot on the tick rather than the live trace.
      // Both are `Equatable`, so on the other nine frames SwiftUI compares
      // equal and never enters the chart's body at all.
      .onChange(of: Int(seconds.rounded(.down))) { _, _ in
        drawnTrace = trace
        // Over a second rather than between neighbouring readings. Two
        // readings a hundredth apart differ mostly by noise, and a rate
        // computed from them is unreadable however true it is.
        flow = trace.flow(at: seconds, window: 1)
      }
      // The other half of the sync. Pressing stop on the scale holds the
      // phone's clock, through the same control the Pause button uses.
      //
      // Keyed on the count rather than the button, so a second stop after a
      // resume is noticed. Only a press arrives here: a scale that goes out of
      // range clears the button instead of reporting one, so losing Bluetooth
      // cannot end a brew.
      .onChange(of: scale.buttonCount) { _, _ in
        let reaction = ScaleControl.reaction(to: scale.lastButton, clockIsHeld: clock.isHeld)
        if reaction == .holdTheClock {
          clock.hold(raw: raw)
        }
      }
      // The scale reports no key events, and a stopped one sends its final
      // time and then goes quiet. So silence is the signal, not a repeated
      // value: no timer message for a few seconds during a brew means the
      // scale stopped. Checked on the tick, because silence has no event.
      .onChange(of: Int(seconds.rounded(.down))) { _, _ in
        guard startSignal.hasSent, scale.state.isConnected, !clock.isHeld,
              let last = scale.lastTimerAt,
              Date.now.timeIntervalSince(last) > Self.scaleSilence
        else { return }
        // At the time the scale reported, not at the moment the silence was
        // noticed. The scale's last message holds its final reading, and using
        // it keeps the two clocks agreeing rather than banking the delay.
        pausedBy = .scale
        clock.hold(showing: scale.scaleSeconds ?? seconds)
      }
      // The faster of the two paths, and the reason both exist. When the
      // scale does repeat its final time, that repeat arrives in about a
      // second, where silence takes three. Whichever notices first wins.
      .onChange(of: scale.timerStateChanges) { _, _ in
        guard startSignal.hasSent else { return }
        if scale.timerHasPaused, !clock.isHeld {
          pausedBy = .scale
          clock.hold(showing: scale.scaleSeconds ?? seconds)
        } else if scale.timerIsRunning == true, clock.isHeld {
          // A scale that speaks again has been restarted, so let the brew go.
          clock.release(raw: raw)
        }
      }
    }
    .navigationTitle("Brewing")
    .navigationBarTitleDisplayMode(.inline)
    // Outside the timeline on purpose. A toolbar rebuilt every second is a
    // control whose state SwiftUI is free to discard, and it discarded the hold.
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button(clock.isHeld ? "Resume" : "Pause", action: toggleHold)
          .fontWeight(.semibold)
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Stop", role: .destructive) { dismiss() }
      }
    }
    // A brew is followed with the phone on the counter and wet hands. Nothing
    // touches the screen for three minutes, so stop it going dark.
    .onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
      // Zero the scale now rather than at 0:00. A scale left running from an
      // earlier brew would otherwise carry on from wherever it stopped, and
      // resetting it alongside the start would beep twice at the one moment
      // that wants a single unambiguous beep.
      scale.send(.resetTimer)
    }
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
  let isHeld: Bool
  let hasScale: Bool

  private var isCountingDown: Bool {
    countdown > 0
  }

  private var shown: BrewTime {
    isCountingDown ? BrewTime(seconds: countdown) : progress.elapsed
  }

  /// Amber while held, because a stopped clock that looks like a running one is
  /// the one state that must never pass at a glance.
  private var tint: Color {
    if isHeld {
      return .orange
    }
    return isCountingDown ? .red : .primary
  }

  var body: some View {
    VStack(spacing: 4) {
      Text(shown.formatted)
        .font(.system(size: 68, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
        .foregroundStyle(tint)
      ProgressView(value: isCountingDown ? 0 : progress.fraction)
        .tint(progress.isComplete ? .green : .accentColor)
      // Under the bar and out of the way. It answers one question, asked only
      // occasionally: is the scale still there. With no scale it leaves no gap
      // behind, and the screen is the one it was before any of this existed.
      if hasScale {
        HStack(spacing: 4) {
          Spacer()
          Image(systemName: "scalemass.fill")
          Text("Scale")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scale connected")
      }
    }
    .padding(.vertical, 8)
  }
}

/// What to do now, large enough to read from across the counter.
private struct CurrentStep: View {
  let recipe: Recipe
  let progress: BrewProgress

  /// Closed to start with, and kept across brews rather than reset each time.
  /// Whether the instructions are wanted is a property of how well the recipe
  /// is known, not of today, and by now the recipe is known.
  @AppStorage("stepInstructionsShown") private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Text(progress.step.title)
          .font(.title2.weight(.semibold))
        Spacer()
        SwitchBadge(position: progress.step.switchPosition)
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }

      if isExpanded {
        ForEach(recipe.instructions(for: progress.step), id: \.self) { line in
          InstructionRow(text: line)
        }
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
    // The whole card, not the chevron. A target the size of a fingertip is
    // the wrong one to aim at with a kettle in the other hand.
    .contentShape(.rect)
    .onTapGesture { withAnimation(.snappy) { isExpanded.toggle() } }
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

/// Who stopped the clock.
///
/// Worth saying. A pause nobody remembers causing is a knocked scale or a
/// stray press, and knowing which end it came from is the difference between
/// carrying on and looking at the counter.
enum PauseSource {
  case phone
  case scale
}

/// What a held brew says.
///
/// The clock stops and the kettle does not, so a long hold leaves the recipe's
/// temperatures behind even though the times still line up. Better said once,
/// here, than discovered in the cup.
private struct HeldNote: View {
  let source: PauseSource

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        if source == .scale {
          Image(systemName: "scalemass.fill")
        }
        Text(source == .scale ? "Paused on the scale" : "Paused")
      }
      .font(.title2.weight(.semibold))
      .foregroundStyle(source == .scale ? Color.orange : .primary)
      Text("The clock has stopped. The kettle has not.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 16))
  }
}

#Preview {
  NavigationStack {
    TimerView(
      recipe: .switchWaterAndTempManaged,
      brew: RunningBrew(tappedAt: .now),
      scale: ScaleConnection()
    )
  }
}
