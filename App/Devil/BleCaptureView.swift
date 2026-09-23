import DevilKit
import DevilProbe
import SwiftUI
import UniformTypeIdentifiers

/// Records an unknown Bluetooth device.
///
/// Built for the ThermoMaven, whose frames nobody has decoded. Point it at a
/// device, subscribe to everything, and note what the instrument's own display
/// said as you go. The capture leaves as a text file, which is the part
/// LightBlue cannot do and the reason this screen exists.
struct BleCaptureView: View {
  @State private var capture = BleCapture()
  @State private var reading = ""
  @State private var saved: URL?

  var body: some View {
    List {
      Section {
        LabeledContent("State", value: capture.status)
        if capture.isConnected {
          Button("Disconnect") { capture.disconnect() }
        } else {
          Button("Scan") { capture.startScanning() }
        }
      } footer: {
        Text("Subscribes to every characteristic that notifies, not one at a time.")
      }

      if !capture.isConnected, !capture.found.isEmpty {
        Section("Advertising") {
          ForEach(capture.found.sorted { $0.strength > $1.strength }) { device in
            Button { capture.connect(device) } label: {
              LabeledContent(device.name, value: "\(device.strength) dBm")
            }
          }
        }
      }

      if capture.isConnected {
        Section {
          HStack {
            TextField("What the display says", text: $reading)
              .keyboardType(.numbersAndPunctuation)
            Button("Mark") {
              capture.mark(reading)
              reading = ""
            }
            .disabled(reading.isEmpty)
          }
        } header: {
          Text("Reading")
        } footer: {
          Text("A frame means nothing on its own. Mark the display as you heat and cool.")
        }
      }

      if let probe = capture.probe {
        Section {
          LabeledContent("Tip", value: degrees(probe.tipCelsius))
          ForEach(Array(probe.zonesCelsius.enumerated()), id: \.offset) { index, zone in
            LabeledContent("Zone \(index + 1)", value: degrees(zone))
          }
          LabeledContent("Ambient", value: degrees(probe.ambientCelsius))
          if let battery = probe.batteryValue {
            LabeledContent("Probe battery", value: "\(battery) %")
          }
        } header: {
          Text("Probe")
        } footer: {
          Text("\(capture.reports) reports. The wire carries tenths of a degree "
            + "Fahrenheit; these are converted.")
        }
      }

      if !capture.map.isEmpty {
        Section("Characteristics") {
          ForEach(capture.map, id: \.self) { line in
            Text(line).font(.caption2.monospaced())
          }
        }
      }

      Section {
        Button("Save capture") { saved = write() }
          .disabled(capture.frames.isEmpty)
        if let saved {
          ShareLink(item: saved) {
            Label("Share \(saved.lastPathComponent)", systemImage: "square.and.arrow.up")
          }
        }
        if !capture.frames.isEmpty {
          Button("Clear", role: .destructive) {
            capture.clear()
            saved = nil
          }
        }
      } header: {
        Text("\(capture.frames.count) frames")
      }

      Section("Log") {
        // Only the newest. The whole capture goes out as a file; this is here
        // to see that something is arriving.
        ForEach(capture.frames.prefix(30)) { frame in
          VStack(alignment: .leading, spacing: 2) {
            Text(frame.note.map { "MARK  \($0)" } ?? frame.source)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(frame.note == nil ? .secondary : .primary)
            if let bytes = frame.bytes {
              Text(BleCapture.hex(bytes))
                .font(.caption2.monospaced())
                .lineLimit(3)
            }
          }
        }
      }
    }
    .navigationTitle("Capture")
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear { capture.stopScanning() }
  }

  private func degrees(_ value: Double) -> String {
    String(format: "%.1f \u{00B0}C", value)
  }

  /// Written into Documents, so the share sheet has a real file to hand over
  /// and the capture survives the app being closed.
  private func write() -> URL? {
    let name = "capture-\(Int(Date.now.timeIntervalSince1970)).txt"
    guard let directory = FileManager.default.urls(
      for: .documentDirectory, in: .userDomainMask
    ).first else { return nil }
    let url = directory.appending(path: name)
    try? capture.text.write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}
