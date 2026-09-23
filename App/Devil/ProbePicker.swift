import DevilKit
import SwiftUI

/// Choosing a probe, which happens once.
///
/// `ScalePicker`'s shape. Scanning starts when this appears and stops when it
/// goes, because a scan left running costs battery with nobody watching it.
struct ProbePicker: View {
  let probe: ProbeConnection
  @Environment(\.dismiss) private var dismiss
  @State private var searchedLongEnough = false

  var body: some View {
    NavigationStack {
      Group {
        switch probe.state {
        case .bluetoothOff:
          ProbeAdvice(
            title: "Bluetooth is off",
            detail: "Turn it on in Control Centre or Settings."
          )
        case .unauthorised:
          ProbeAdvice(
            title: "Devil cannot use Bluetooth",
            detail: "Allow it in Settings, under Privacy."
          )
        default:
          list
        }
      }
      .navigationTitle("Choose a probe")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium])
    .task {
      probe.startScanning()
      try? await Task.sleep(for: .seconds(5))
      searchedLongEnough = true
    }
    .onDisappear { probe.stopScanning() }
    .onChange(of: probe.state.isConnected) { _, connected in
      if connected {
        dismiss()
      }
    }
  }

  private var list: some View {
    List {
      Section {
        ForEach(probe.found) { found in
          Button {
            probe.choose(found)
          } label: {
            HStack {
              Text(found.name)
              Spacer()
              Text(Strength.bars(found.strength))
                .foregroundStyle(.secondary)
                .monospaced()
            }
          }
        }
      } header: {
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text("Searching")
        }
      } footer: {
        // Everything advertising is listed, because the base station's name is
        // whatever Auros set and this app has no business guessing it.
        if probe.found.isEmpty, searchedLongEnough {
          Text(
            """
            Nothing yet. The base station may be off, or out of range. It does \
            not need its own app running.
            """
          )
        }
      }
    }
  }
}

/// The probe's state, in the words that name its remedy.
struct ProbeRow: View {
  let state: ProbeState
  /// Zone one, in Celsius. `nil` while nothing has decoded yet.
  let zone: Double?

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
    case .noneChosen: "Connect a probe"
    case .bluetoothOff: "Bluetooth is off"
    case .unauthorised: "Devil cannot use Bluetooth"
    case let .searching(name): name
    case let .connected(name): name
    }
  }

  private var detail: String? {
    switch state {
    case .noneChosen, .bluetoothOff, .unauthorised: nil
    case .searching: "not found"
    // The reading is the proof the stream is alive, so it is the only thing
    // worth the space. A count told you frames arrived, not that they meant
    // anything.
    case .connected: zone.map(Format.degrees) ?? "waiting"
    }
  }
}

private struct ProbeAdvice: View {
  let title: String
  let detail: String

  var body: some View {
    ContentUnavailableView {
      Text(title)
    } description: {
      Text(detail)
    } actions: {
      Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
    }
  }
}
