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
  let settings: BrewSettings
  let brew: RunningBrew
  let scale: ScaleConnection
  /// Set when you ask for the notes, so the screen behind can open them once
  /// this one has gone.
  @Binding var notesFor: BrewRecord?

  let store = BrewLogStore()

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
  @State private var askingToSave = false
  @State private var lockScreen = BrewActivity()
  /// Read by the toolbar, which lives outside the timeline and so learns
  /// nothing from the tick. A change here redraws it once, at the end.
  @State private var hasFinished = false

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

  /// Where the brew stands, read from the clock rather than the timeline, so
  /// the toolbar can stay outside the per-second redraw.
  private var now: BrewProgress {
    let elapsed = clock.elapsed(raw: Date.now.timeIntervalSince(brew.start))
    return recipe.progress(atSeconds: max(0, Int(elapsed.rounded(.down))))
  }

  /// Ends the brew, writing it down unless it never started.
  ///
  /// A brew that has not reached 0:00 leaves nothing. You pressed the wrong
  /// button, and a file for each of those buries the mornings that counted.
  private func finish() {
    guard startSignal.hasSent else { return dismiss() }
    if now.isComplete {
      save()
      dismiss()
    } else {
      // Only you know whether 0:30 was a fumble or a short brew on purpose.
      askingToSave = true
    }
  }

  /// Writes the brew and hands back what landed on disk.
  ///
  /// Read back rather than returned from memory, because the file is the
  /// record and only the file knows whether a sidecar was written.
  @discardableResult
  private func save() -> BrewRecord? {
    let record = BrewRecord.of(
      settings: settings,
      at: BrewStamp(Date.now),
      finished: now.isComplete
    )
    guard let stem = store.save(record, trace: trace) else { return nil }
    return store.brews().first { $0.id == stem }
  }

  /// The offer at the end. Right after drinking is the one moment you would
  /// write down how it tasted, and the log fills only if the app says so.
  private func addNotes() {
    notesFor = save()
    dismiss()
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
      // Started at 0:00 rather than at the tap, so the Lock Screen clock and
      // the one on this screen agree. The 3-2-1 is not part of the brew.
      .onChange(of: startSignal.hasSent) { _, sent in
        guard sent else { return }
        lockScreen.start(recipe: recipe, from: brew.start, servings: settings.servings)
      }
      // The only messages sent all brew: one a step, and one when the clock
      // stops or starts again. The clock itself is drawn from the dates.
      .onChange(of: progress.stepIndex) { _, _ in
        lockScreen.update(recipe: recipe, at: progress, heldAt: nil)
      }
      .onChange(of: clock.isHeld) { _, held in
        lockScreen.update(recipe: recipe, at: progress, heldAt: held ? seconds : nil)
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
      // The toolbar sits outside the timeline, so it has to be told.
      // `initial` matters: a brew opened at a time past its end is complete
      // from the first draw, so the value never changes and the offer would
      // never appear.
      .onChange(of: progress.isComplete, initial: true) { _, complete in
        hasFinished = complete
      }
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
      if hasFinished {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Add notes", action: addNotes)
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        // `Done`, and not red. Reaching the end of a recipe is the ordinary
        // way out, and a destructive button reads as abandoning the brew.
        Button("Done", action: finish)
          .fontWeight(hasFinished ? .semibold : .regular)
      }
    }
    .confirmationDialog(
      "Save this brew?",
      isPresented: $askingToSave,
      titleVisibility: .visible
    ) {
      Button("Save") {
        save()
        dismiss()
      }
      Button("Discard", role: .destructive) { dismiss() }
    } message: {
      Text("It stopped before the end.")
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
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
      // However the brew ended, the Lock Screen should not still be running
      // it. `end` also clears one left behind by an app that was killed.
      lockScreen.end()
    }
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
