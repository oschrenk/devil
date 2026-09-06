import DevilKit
import SwiftUI

struct ContentView: View {
  @State private var settings = BrewSettings.one
  /// Non-nil while a brew is running.
  @State private var running: RunningBrew?
  @State private var scale = ScaleConnection()
  @State private var picking = false

  private var recipe: Recipe {
    .switchWaterAndTempManaged(for: settings)
  }

  private var cupsLabel: String {
    guard settings.servings > 1 else { return "Cup" }
    return "Cups, \(settings.servings) x \(Format.number(settings.preheat.perCup))"
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
        Section("Brewing for") {
          Stepper(value: $settings.servings, in: BrewSettings.servingsRange) {
            LabelledValue(
              label: settings.servings == 1 ? "1 person" : "\(settings.servings) people",
              value: recipe.dose.grams
            )
          }
          Picker("Filter", selection: $settings.filter) {
            Text("Hario").tag(Filter.harioV60Size02)
            Text("Abaca").tag(Filter.abaca)
          }
          Picker("Grinder", selection: $settings.grinder) {
            ForEach(Grinder.all, id: \.self) { grinder in
              Text(grinder.name).tag(grinder)
            }
          }
          Stepper(
            value: $settings.grindSetting,
            in: settings.grindRange,
            step: 0.1
          ) {
            LabelledValue(label: "Grind", value: Format.grind(recipe.grindSetting))
          }
        }
        // Picking the paper moves the grind to what that paper usually wants.
        // Dialling in from there is the point of the stepper, so the snap only
        // happens on the change and never undoes a later edit.
        .onChange(of: settings.filter) { _, filter in
          settings.grindSetting = settings.grinder.clamped(filter.defaultGrind)
        }
        // The stepper's bounds are the new dial's the moment this changes, so
        // a setting the new grinder cannot reach has to come with it.
        .onChange(of: settings.grinder) { _, grinder in
          settings.use(grinder)
        }

        Section("Temperature") {
          Stepper(value: $settings.brewTemperature, in: 85 ... 96, step: 1) {
            LabelledValue(label: "Kettle", value: recipe.brewTemperature.degrees)
          }
          Stepper(value: $settings.temperatureTarget, in: 65 ... 85, step: 1) {
            LabelledValue(label: "Last pour", value: recipe.temperatureTarget.degrees)
          }
        }

        Section {
          LabelledValue(label: "Boil", value: recipe.tapToBoil.millilitres)
            .fontWeight(.semibold)
          Stepper(value: $settings.preheat.cone, in: 0 ... 400, step: 10) {
            LabelledValue(label: "Cone", value: recipe.preheat.cone.millilitres)
          }
          Stepper(value: $settings.preheat.vessel, in: 0 ... 300, step: 10) {
            LabelledValue(label: "Vessel", value: recipe.preheat.vessel.millilitres)
          }
          Stepper(value: $settings.preheat.perCup, in: 0 ... 200, step: 10) {
            LabelledValue(label: cupsLabel, value: recipe.preheat.cups.millilitres)
          }
        } header: {
          Text("Preheat")
        } footer: {
          Text(boilBreakdown)
        }

        Section("Kettle") {
          LabelledValue(label: "Tap", value: recipe.kettleFill.tap.grams)
          LabelledValue(label: "Beaker A", value: recipe.kettleFill.demineralized.grams)
            .accessibilityLabel("Beaker A, demineralized water for the kettle")
          LabelledValue(label: "Beaker B", value: recipe.cooler.amount.grams)
            .accessibilityLabel("Beaker B, cold demineralized water")
        }

        Section("Pours") {
          ForEach(recipe.steps, id: \.start) { step in
            StepRow(step: step)
          }
        }

        Section {
          LabelledValue(label: "Through the bed", value: recipe.waterThroughBed.grams)
          LabelledValue(label: "Ratio", value: Format.ratio(recipe.brewRatio))
          LabelledValue(label: "Finish", value: recipe.finish?.formatted ?? "not timed")
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
      // Top left, and not a row in the form. The `Scale` section earns a row
      // because you read its state before brewing. The log holds no state
      // that belongs on this screen, and a toolbar button costs no scrolling
      // past the steppers at six in the morning.
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          NavigationLink {
            BrewLogView(store: BrewLogStore())
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
    .sheet(isPresented: $picking) {
      ScalePicker(scale: scale)
    }
    // Connect when the app opens, not when a brew starts. The scale sleeps
    // after five minutes when idle and disconnected, and grinding and
    // preheating take longer than that. A connected app keeps it awake.
    .task { scale.begin() }
    .fullScreenCover(item: $running) { brew in
      NavigationStack {
        TimerView(recipe: recipe, settings: settings, brew: brew, scale: scale)
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

private extension Double {
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
