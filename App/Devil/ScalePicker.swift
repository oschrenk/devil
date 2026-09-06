import DevilKit
import SwiftUI

/// Choosing a scale, which happens once.
///
/// Scanning starts when this appears and stops when it goes, because a scan
/// left running costs battery with nobody watching it. Two of its states are
/// not a list at all and need a button rather than a spinner.
struct ScalePicker: View {
  let scale: ScaleConnection
  @Environment(\.dismiss) private var dismiss
  @State private var searchedLongEnough = false

  var body: some View {
    NavigationStack {
      Group {
        switch scale.state {
        case .bluetoothOff:
          Advice(
            title: "Bluetooth is off",
            detail: "Turn it on in Control Centre or Settings."
          )
        case .unauthorised:
          Advice(
            title: "Devil cannot use Bluetooth",
            detail: "Allow it in Settings, under Privacy."
          )
        default:
          list
        }
      }
      .navigationTitle("Choose a scale")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium])
    .task {
      scale.startScanning()
      try? await Task.sleep(for: .seconds(5))
      searchedLongEnough = true
    }
    .onDisappear { scale.stopScanning() }
    .onChange(of: scale.state.isConnected) { _, connected in
      if connected {
        dismiss()
      }
    }
  }

  private var list: some View {
    List {
      Section {
        ForEach(scale.found) { found in
          Button {
            scale.choose(found)
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
        // The three causes look identical from here, and one of them costs an
        // hour if it goes unnamed.
        if scale.found.isEmpty, searchedLongEnough {
          Text(
            """
            Nothing yet. The scale may be off, its own Bluetooth setting may \
            read Off, or the Acaia app may still be holding it.
            """
          )
        }
      }
    }
  }
}

/// A signal strength as bars, because a number in dBm helps nobody choose.
enum Strength {
  static func bars(_ rssi: Int) -> String {
    let filled = switch rssi {
    case ...(-90): 1
    case ...(-75): 2
    case ...(-60): 3
    default: 4
    }
    return String(repeating: "▮", count: filled) + String(repeating: "▯", count: 4 - filled)
  }
}

private struct Advice: View {
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
      .buttonStyle(.borderedProminent)
    }
  }
}
