@preconcurrency import CoreBluetooth
import DevilKit
import DevilProbe
import Foundation

/// What the probe row says, and why each state needs its own line.
///
/// The same five as the scale's, for the same reason: switching Bluetooth on,
/// choosing a probe and switching the probe on are three different actions.
enum ProbeState: Equatable {
  case bluetoothOff
  case unauthorised
  case noneChosen
  case searching(name: String)
  case connected(name: String)

  var isConnected: Bool {
    if case .connected = self {
      return true
    }
    return false
  }
}

/// The link to a ThermoMaven base station.
///
/// `ScaleConnection`'s shape, and easier in two ways. The probe needs no
/// handshake and no heartbeat: subscribe and it streams. And it never drives
/// the clock, so losing it during a brew costs a curve rather than a brew.
///
/// `DevilKit` and `DevilProbe` own the protocol. This file only stays
/// connected and hands bytes across.
@Observable
final class ProbeConnection: NSObject {
  private(set) var state: ProbeState = .noneChosen
  private(set) var found: [FoundScale] = []
  /// The last report, whole. `nil` until three frames have arrived.
  private(set) var probe: ProbeReport.Probe?
  /// How many reports have decoded. What a view watches, because two
  /// identical readings are still two readings.
  private(set) var reports = 0

  private var rememberedID: UUID? {
    get { UserDefaults.standard.string(forKey: Self.key).flatMap(UUID.init(uuidString:)) }
    set { UserDefaults.standard.set(newValue?.uuidString, forKey: Self.key) }
  }

  private static let key = "probe.peripheral"
  // Instance rather than static: CBUUID is not Sendable.
  private let service = CBUUID(string: "0000FFFF-0000-1000-8000-00805F9B34FB")
  private let notify = CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")

  private var central: CBCentralManager?
  private var peripheral: CBPeripheral?
  private var blufi = BlufiDecoder()

  /// Built on first use, never at launch, so iOS raises the Bluetooth prompt
  /// when you ask for a probe rather than when you open the app.
  func begin() {
    guard central == nil else { return }
    central = CBCentralManager(delegate: self, queue: .main)
  }

  func startScanning() {
    begin()
    found = []
    guard central?.state == .poweredOn else { return }
    central?.scanForPeripherals(withServices: nil)
  }

  func stopScanning() {
    central?.stopScan()
  }

  func choose(_ device: FoundScale) {
    rememberedID = device.id
    stopScanning()
    connectToRemembered()
  }

  func forget() {
    rememberedID = nil
    if let peripheral {
      central?.cancelPeripheralConnection(peripheral)
    }
    peripheral = nil
    probe = nil
    state = .noneChosen
  }

  private func connectToRemembered() {
    guard let central, central.state == .poweredOn, let id = rememberedID else { return }
    guard let known = central.retrievePeripherals(withIdentifiers: [id]).first else {
      state = .searching(name: "Probe")
      central.scanForPeripherals(withServices: nil)
      return
    }
    peripheral = known
    known.delegate = self
    state = .searching(name: known.name ?? "Probe")
    central.connect(known)
  }
}

extension ProbeConnection: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      if rememberedID == nil {
        state = .noneChosen
      } else {
        connectToRemembered()
      }
    case .unauthorized:
      state = .unauthorised
    default:
      state = .bluetoothOff
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
    guard let name = advertised ?? peripheral.name, !name.isEmpty else { return }

    if peripheral.identifier == rememberedID {
      central.stopScan()
      self.peripheral = peripheral
      peripheral.delegate = self
      central.connect(peripheral)
      return
    }
    guard !found.contains(where: { $0.id == peripheral.identifier }) else { return }
    found.append(FoundScale(id: peripheral.identifier, name: name, strength: RSSI.intValue))
  }

  func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
    blufi = BlufiDecoder()
    peripheral.discoverServices([service])
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error _: Error?
  ) {
    probe = nil
    state = rememberedID == nil ? .noneChosen : .searching(name: peripheral.name ?? "Probe")
    // Reconnect on its own, the way the scale does. A probe carried out of
    // the kitchen and brought back should not need the picker again.
    if rememberedID != nil {
      central.connect(peripheral)
    }
  }
}

extension ProbeConnection: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
    for found in peripheral.services ?? [] {
      peripheral.discoverCharacteristics([notify], for: found)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error _: Error?
  ) {
    for characteristic in service.characteristics ?? [] where characteristic.uuid == notify {
      peripheral.setNotifyValue(true, for: characteristic)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error _: Error?
  ) {
    guard characteristic.uuid == notify, characteristic.isNotifying else { return }
    state = .connected(name: peripheral.name ?? "Probe")
  }

  func peripheral(
    _: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error _: Error?
  ) {
    guard let value = characteristic.value else { return }
    for message in blufi.append([UInt8](value)) {
      guard let found = ProbeReport.decode(message: message)?.cmdData.probes.first
      else { continue }
      probe = found
      reports += 1
    }
  }
}
