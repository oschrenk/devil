import DevilKit
import SwiftUI

struct ContentView: View {
  @State private var defaults = BrewDefaults()
  @State private var settings = BrewSettings.one
  /// Non-nil while a brew is running.
  @State private var running: RunningBrew?
  /// The brew whose notes to open, set by the timer as it closes.
  @State private var notesFor: BrewRecord?
  @State private var scale = ScaleConnection()
  @State private var probe = ProbeConnection()
  @State private var picking = false
  @State private var pickingProbe = false

  private var dialAndSize: String {
    let size = Format.microns(settings.grindMicrons)
    return "\(settings.grindSetting.formatted)  \u{00B7}  \(size)"
  }

  private var recipe: Recipe {
    .switchWaterAndTempManaged(for: settings)
  }

  private var cupsLabel: String {
    guard settings.servings > 1 else { return "Cup" }
    return "Cups, \(settings.servings) x \(Format.number(settings.preheat.perCup))"
  }

  /// What the kettle starts at, and what the last pour should reach.
  private var temperatureSummary: String {
    "\(recipe.brewTemperature.degrees) / \(recipe.temperatureTarget.degrees)"
  }

  /// The water through the bed and when it should be done, which is what the
  /// steps below add up to.
  private var recipeSummary: String {
    let time = recipe.finish ?? recipe.totalTime
    return "\(recipe.waterThroughBed.grams) in \(time.formatted)"
  }

  /// Says where the boil figure comes from, so it can be checked rather than
  /// trusted.
  private var boilBreakdown: String {
    let preheat = recipe.preheat.total.millilitres
    let tap = recipe.kettleFill.tap.millilitres
    let slack = recipe.preheat.safety.millilitres
    return "\(preheat) of preheat, plus \(tap) of brew tap and \(slack) of slack."
  }

  var body: some View {
    NavigationStack {
      Form {
        FoldingSection("Brewing") { isOpen in
          Stepper(value: $settings.servings, in: BrewSettings.servingsRange) {
            LabelledValue(
              label: settings.servings == 1 ? "1 person" : "\(settings.servings) people",
              value: recipe.dose.grams
            )
          }
          if isOpen {
            // First, under the dose it belongs to. The ratio is what you check
            // when you change the number of people, so it reads with that row
            // rather than three sections further down.
            LabelledValue(label: "Ratio", value: Format.ratio(recipe.brewRatio))
            Picker("Filter", selection: $settings.filter) {
              ForEach(Filter.all) { paper in
                Text(paper.name).tag(paper)
              }
            }
            Picker("Grinder", selection: $settings.grinder) {
              ForEach(Grinder.all) { grinder in
                Text(grinder.name).tag(grinder)
              }
            }
            // Plus and minus move one detent on the grinder in front of you,
            // not a round number of microns. A click near the middle of a dial
            // moves the grind several times further than one near an end.
            Stepper {
              LabelledValue(
                label: "Grind",
                value: settings.grinderCanReach ? dialAndSize : "out of range"
              )
            } onIncrement: {
              settings.grindMicrons = settings.grinder.stepped(settings.grindMicrons, by: 1)
            } onDecrement: {
              settings.grindMicrons = settings.grinder.stepped(settings.grindMicrons, by: -1)
            }
          }
        }

        FoldingSection("Temperature", summary: temperatureSummary) { isOpen in
          if isOpen {
            Stepper(value: $settings.brewTemperature, in: 85 ... 96, step: 1) {
              LabelledValue(label: "Kettle", value: recipe.brewTemperature.degrees)
            }
            Stepper(value: $settings.temperatureTarget, in: 65 ... 85, step: 1) {
              LabelledValue(label: "Last pour", value: recipe.temperatureTarget.degrees)
            }
          }
        }

        FoldingSection(
          "Preheat",
          summary: recipe.preheat.total.millilitres,
          footer: "Cup is per person. The rest are the same however many are drinking."
        ) { isOpen in
          if isOpen {
            Stepper(value: $settings.preheat.cone, in: 0 ... 400, step: PreheatPlan.step) {
              LabelledValue(label: "Cone", value: recipe.preheat.cone.millilitres)
            }
            Stepper(value: $settings.preheat.vessel, in: 0 ... 300, step: PreheatPlan.step) {
              LabelledValue(label: "Vessel", value: recipe.preheat.vessel.millilitres)
            }
            Stepper(value: $settings.preheat.perCup, in: 0 ... 200, step: PreheatPlan.step) {
              LabelledValue(label: cupsLabel, value: recipe.preheat.cups.millilitres)
            }
            // The slack is not preheat and does not warm anything. It is here
            // because it is the fourth thing that goes into the boil, and the
            // boil figure above is the sum of all four.
            Stepper(value: $settings.preheat.safety, in: 0 ... 100, step: PreheatPlan.step) {
              LabelledValue(label: "Slack", value: recipe.preheat.safety.millilitres)
            }
          }
        }

        // Was `Pours`, and was followed by a section repeating the water and
        // the finish. Closed, the header says both, so that section went.
        FoldingSection("Recipe", summary: recipeSummary) { isOpen in
          if isOpen {
            ForEach(recipe.steps, id: \.start) { step in
              StepRow(step: step)
            }
            LabelledValue(label: "Through the bed", value: recipe.waterThroughBed.grams)
            LabelledValue(label: "Finish", value: recipe.finish?.formatted ?? "not timed")
          }
        }

        // Above `Start brewing` rather than at the top, because the scale is
        // optional. Left alone this is one quiet row and nothing else changes.
        Section("Scale") {
          Button { picking = true } label: {
            ScaleRow(state: scale.state)
          }
          .tint(.primary)
          if scale.state.isConnected {
            Button("Tare") { scale.send(.tare) }
          }
        }

        // Below the scale, and optional in the same way. Left alone it is one
        // quiet row and the app behaves exactly as it does without a probe.
        Section("Probe") {
          Button { pickingProbe = true } label: {
            ProbeRow(state: probe.state, zone: probe.probe?.zonesCelsius.first)
          }
          .tint(.primary)
          // Shown only while a probe is connected and silent. Waiting has
          // several causes, and these separate them: no write channel, or
          // nothing written, or written and ignored.
          if probe.state.isConnected, probe.probe == nil {
            LabelledValue(label: "Can ask", value: probe.canWrite ? "yes" : "NO")
            LabelledValue(label: "Sent", value: "\(probe.framesSent)")
            LabelledValue(label: "Heard", value: "\(probe.framesHeard)")
            LabelledValue(label: "Account", value: probe.userId ?? "unknown")
            if let refusal = probe.refusal {
              LabelledValue(label: "Refused", value: "error \(refusal)")
            }
            Button("Ask again") { probe.ask() }
          }
        }

        Section {
          // What to measure out. The first two go in the kettle and boil.
          // The last waits in its own beaker and goes in cold.
          //
          // The whole boil is tap water, so the row says so. What that figure
          // is made of is in the footer rather than a row of its own.
          LabelledValue(label: "Tap", value: recipe.tapToBoil.millilitres)
          LabelledValue(label: "Demineralised", value: recipe.kettleFill.demineralized.grams)
            .accessibilityLabel("Demineralised water, into the kettle")
          LabelledValue(label: "Cooling", value: recipe.cooler.amount.grams)
            .accessibilityLabel("Cooling water, demineralised and held back")
        } header: {
          Text("Water")
        } footer: {
          Text(boilBreakdown)
        }

        Section {
          Button {
            // Ignore a second press while one is already running. A stray tap
            // during the cover's animation would otherwise start a new brew
            // and drop the one in progress.
            guard running == nil else { return }
            running = RunningBrew(tappedAt: .now)
          } label: {
            Label("Start brewing", systemImage: "play.fill")
              .frame(maxWidth: .infinity)
          }
          .font(.headline)
        }
      }
      .navigationTitle(recipe.brewer)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            DefaultsView(defaults: defaults)
          } label: {
            Label("Defaults", systemImage: "gearshape")
          }
        }
      }
      // Top left, and not a row in the form. The `Scale` section earns a row
      // because you read its state before brewing. The log holds no state
      // that belongs on this screen, and a toolbar button costs no scrolling
      // past the steppers at six in the morning.
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          NavigationLink {
            BrewLogView(store: BrewLogStore(), scale: scale, defaults: defaults)
          } label: {
            Label("Brews", systemImage: "list.bullet.rectangle")
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .monospacedDigit()
    }
    // A cover, not a push. A running brew is an activity rather than a place:
    // it should not sit on a navigation stack where a stray back-swipe ends it,
    // and a push destination inside a Form can deactivate on its own, which it
    // did, closing the timer part-way through a brew.
    .sheet(isPresented: $pickingProbe) {
      ProbePicker(probe: probe)
    }
    .sheet(isPresented: $picking) {
      ScalePicker(scale: scale)
    }
    // Connect when the app opens, not when a brew starts. The scale sleeps
    // after five minutes when idle and disconnected, and grinding and
    // preheating take longer than that. A connected app keeps it awake.
    // The settings screen decides what a brew opens with, and one counter
    // covers every value on it. Watching nine properties one at a time is
    // nine chances to forget the tenth.
    //
    // A change here replaces what is on screen, including anything nudged for
    // today. Setting a default is a deliberate act, so the newer number wins.
    .onChange(of: defaults.revision, initial: true) { _, _ in
      let servings = settings.servings
      settings = defaults.settings()
      settings.servings = servings
    }
    .task { scale.begin() }
    .task { probe.begin() }
    // A sheet rather than a push, because the timer it follows is a cover and
    // there is no stack underneath to push onto.
    .sheet(item: $notesFor) { brew in
      NavigationStack {
        BrewDetailView(store: BrewLogStore(), brew: brew, scale: scale, defaults: defaults)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button("Close") { notesFor = nil }
            }
          }
      }
    }
    .fullScreenCover(item: $running) { brew in
      NavigationStack {
        TimerView(
          recipe: recipe,
          settings: settings,
          brew: brew,
          scale: scale,
          probe: probe,
          notesFor: $notesFor
        )
      }
    }
  }
}

/// A brew in progress, identified by when it started.
///
/// The wrapper exists so the cover is presented once per brew. Keying it on a
/// bare `Date?` would rebuild the timer whenever the parent redrew.
struct RunningBrew: Identifiable, Equatable {
  /// When the button was pressed.
  let tappedAt: Date

  /// When water meets coffee, a lead-in later. This is 0:00 on the brew clock.
  var start: Date {
    tappedAt.addingTimeInterval(Double(Countdown.leadIn))
  }

  var id: Date {
    tappedAt
  }
}

/// The scale's state, in the words that name its remedy.
private struct ScaleRow: View {
  let state: ScaleState

  var body: some View {
    HStack {
      Text(title)
      Spacer()
      if let detail {
        Text(detail).foregroundStyle(.secondary)
      }
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
  }

  private var title: String {
    switch state {
    case .noneChosen: "Connect a scale"
    case .bluetoothOff: "Bluetooth is off"
    case .unauthorised: "Devil cannot use Bluetooth"
    case let .searching(name): name
    case let .connected(name, _): name
    }
  }

  private var detail: String? {
    switch state {
    case .noneChosen, .bluetoothOff, .unauthorised: nil
    case .searching: "not found"
    case let .connected(_, battery): battery.map { "\($0) %" } ?? "connected"
    }
  }
}

/// A label on the left, a figure on the right, the way a spec sheet reads.
struct LabelledValue: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      Text(value)
        .foregroundStyle(.secondary)
    }
  }
}

private struct StepRow: View {
  let step: Step

  /// Grows with the reader's text size. A fixed width holds at the default and
  /// then breaks `0:00` across two lines once the type is larger, which is the
  /// one string in the row that must never wrap.
  @ScaledMetric private var timeWidth: Double = 44

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(step.start.formatted)
        .foregroundStyle(.secondary)
        .fixedSize()
        .frame(minWidth: timeWidth, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        Text(step.title)
        Text(step.switchPosition == .open ? "switch open" : "switch closed")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      Spacer(minLength: 4)
      if step.poured > 0 {
        Text(step.poured.grams)
          .foregroundStyle(.secondary)
          .fixedSize()
      }
    }
  }
}

extension Double {
  var grams: String {
    Format.grams(self)
  }

  var degrees: String {
    Format.degrees(self)
  }

  var millilitres: String {
    "\(Format.number(self)) ml"
  }
}

#Preview {
  ContentView()
}
