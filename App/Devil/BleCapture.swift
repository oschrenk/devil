@preconcurrency import CoreBluetooth
import Foundation

/// A Bluetooth device recorder.
///
/// Deliberately knows nothing about any protocol. It connects to whatever you
/// point it at, subscribes to every characteristic that will notify, and keeps
/// what arrives. `RefractometerConnection` decodes one device it understands;
/// this one is for a device nobody understands yet.
///
/// The marker is the reason it exists. Bytes on their own mean nothing, and a
/// capture is only decodable if it says what the instrument read at the moment
/// each frame arrived. `mark` writes that into the log.
@Observable
final class BleCapture: NSObject {
  struct Frame: Identifiable {
    let id = UUID()
    let time: Date
    /// The characteristic it came from, or a note you typed.
    let source: String
    let bytes: [UInt8]?
    let note: String?
  }

  private(set) var status = "Idle"
  private(set) var found: [FoundScale] = []
  /// Every service and characteristic the device offered, with its properties.
  private(set) var map: [String] = []
  private(set) var frames: [Frame] = []
  private(set) var isConnected = false

  /// Enough for a long temperature sweep, and small enough to hold in memory.
  private static let limit = 4000

  private var central: CBCentralManager?
  private var peripheral: CBPeripheral?

  func begin() {
    guard central == nil else { return }
    central = CBCentralManager(delegate: self, queue: .main)
  }

  func startScanning() {
    begin()
    found = []
    guard central?.state == .poweredOn else { return }
    status = "Scanning"
    central?.scanForPeripherals(withServices: nil)
  }

  func stopScanning() {
    central?.stopScan()
  }

  func connect(_ device: FoundScale) {
    guard let central, let known = central.retrievePeripherals(withIdentifiers: [device.id]).first
    else { return }
    central.stopScan()
    peripheral = known
    known.delegate = self
    status = "\(device.name), connecting"
    central.connect(known)
  }

  func disconnect() {
    if let peripheral {
      central?.cancelPeripheralConnection(peripheral)
    }
  }

  /// What the instrument's own display said, right now.
  func mark(_ reading: String) {
    frames.insert(
      Frame(time: .now, source: "mark", bytes: nil, note: reading), at: 0
    )
  }

  func clear() {
    frames = []
  }

  /// The capture as a file, newest last so it reads in the order it happened.
  var text: String {
    var lines = ["# Devil BLE capture", "# \(Date.now.ISO8601Format())", ""]
    lines += map.map { "# \($0)" }
    lines.append("")
    for frame in frames.reversed() {
      let stamp = Self.stamp.string(from: frame.time)
      if let note = frame.note {
        lines.append("\(stamp)  MARK  \(note)")
      } else if let bytes = frame.bytes {
        lines.append("\(stamp)  \(frame.source)  \(Self.hex(bytes))")
      }
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private static let stamp: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
  }()

  static func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
  }

  private func record(_ source: String, _ bytes: [UInt8]) {
    frames.insert(Frame(time: .now, source: source, bytes: bytes, note: nil), at: 0)
    if frames.count > Self.limit {
      frames.removeLast()
    }
  }
}

extension BleCapture: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn: status = "Idle"
    case .unauthorized: status = "Bluetooth refused"
    default: status = "Bluetooth is off"
    }
  }

  func centralManager(
    _: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
    guard let name = advertised ?? peripheral.name, !name.isEmpty else { return }
    guard !found.contains(where: { $0.id == peripheral.identifier }) else { return }
    found.append(FoundScale(id: peripheral.identifier, name: name, strength: RSSI.intValue))
  }

  func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
    isConnected = true
    map = []
    status = "\(peripheral.name ?? "Device"), mapping"
    peripheral.discoverServices(nil)
  }

  func centralManager(
    _: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error _: Error?
  ) {
    isConnected = false
    status = "Disconnected"
    // Straight back in. A device that drops the link between bursts would
    // otherwise end the capture, and we do not yet know whether this one does.
    if self.peripheral === peripheral {
      central?.connect(peripheral)
    }
  }
}

extension BleCapture: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
    for service in peripheral.services ?? [] {
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error _: Error?
  ) {
    for characteristic in service.characteristics ?? [] {
      map.append("\(short(service.uuid)) / \(short(characteristic.uuid))"
        + "  \(properties(characteristic.properties))")
      // Everything that will talk, not one at a time. Which characteristic
      // carries the data is the question, so subscribe to all of them.
      let talks: CBCharacteristicProperties = [.notify, .indicate]
      if !characteristic.properties.isDisjoint(with: talks) {
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }
    status = "\(peripheral.name ?? "Device"), listening"
  }

  func peripheral(
    _: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error _: Error?
  ) {
    guard let value = characteristic.value else { return }
    let bytes = [UInt8](value)
    record(short(characteristic.uuid), bytes)
  }

  /// `0000ff02-0000-1000-8000-00805f9b34fb` is `ff02` and nothing else.
  private func short(_ uuid: CBUUID) -> String {
    uuid.uuidString.lowercased()
  }

  private func properties(_ value: CBCharacteristicProperties) -> String {
    var names: [String] = []
    if value.contains(.read) {
      names.append("read")
    }
    if value.contains(.write) {
      names.append("write")
    }
    if value.contains(.writeWithoutResponse) {
      names.append("writeNR")
    }
    if value.contains(.notify) {
      names.append("notify")
    }
    if value.contains(.indicate) {
      names.append("indicate")
    }
    return names.joined(separator: ",")
  }
}
