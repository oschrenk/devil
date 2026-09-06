@preconcurrency import CoreBluetooth
import DevilKit
import Foundation

/// What the scale row says, and why each state needs its own line.
///
/// A single "disconnected" would be wrong. Turning Bluetooth on, choosing a
/// scale and switching the scale on are three different actions, and at six in
/// the morning the row has to say which one.
enum ScaleState: Equatable {
  case bluetoothOff
  case unauthorised
  case noneChosen
  case searching(name: String)
  case connected(name: String, battery: Int?)

  var isConnected: Bool {
    if case .connected = self {
      return true
    }
    return false
  }
}

/// A scale seen advertising.
struct FoundScale: Identifiable, Equatable {
  let id: UUID
  let name: String
  let strength: Int
}

/// The link to the scale.
///
/// Holds the central, the peripheral and the heartbeat. Everything about the
/// wire format lives in `DevilKit`, so this file is only about staying
/// connected and handing bytes across.
@Observable
final class ScaleConnection: NSObject {
  private(set) var state: ScaleState = .noneChosen
  private(set) var found: [FoundScale] = []
  private(set) var weight: Double?
  private(set) var scaleSeconds: Double?
  /// The last press, and how many have arrived. The count is what a view
  /// observes: two stops in a row are the same value, and watching the value
  /// alone would notice only the first.
  private(set) var lastButton: AcaiaButton?
  private(set) var buttonCount = 0
  private(set) var firmware: String?
  /// Whether the scale's own clock is moving, worked out from its time. This
  /// scale sends no key events, so its time is the only signal there is.
  private(set) var timerIsRunning: Bool?
  private(set) var timerHasPaused = false
  /// Bumped whenever the answer changes, which is what a view watches: the
  /// same answer arriving twice is not a moment to act on.
  private(set) var timerStateChanges = 0
  /// When the last timer message arrived. A running scale reports every couple
  /// of seconds; a stopped one sends its final time and then says nothing, so
  /// silence is the signal rather than a repeated value.
  private(set) var lastTimerAt: Date?

  /// The scale to reconnect to, remembered across launches. A peripheral's
  /// identifier is stable per app, so this is all it takes to skip the picker
  /// every morning after the first.
  private var rememberedID: UUID? {
    get { UserDefaults.standard.string(forKey: Self.key).flatMap(UUID.init(uuidString:)) }
    set { UserDefaults.standard.set(newValue?.uuidString, forKey: Self.key) }
  }

  private static let key = "scale.peripheral"
  // Instance rather than static: CBUUID is not Sendable, so a static one is a
  // shared mutable global as far as Swift 6 is concerned.
  private let write = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
  private let notify = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")
  /// Standard Device Information Service, firmware revision string. Nothing
  /// Acaia-specific: every BLE device that bothers offers it.
  private let firmwareRevision = CBUUID(string: "2A26")
  /// The scale drops a link that goes quiet. Five seconds is what the
  /// maintained implementations settle on.
  /// One second, not the five the published implementations use. The timer
  /// rides on the heartbeat, and a stopped scale is found by noticing it has
  /// gone quiet, so a faster pulse is a faster answer.
  private static let heartbeat: TimeInterval = 1
  private static let namePrefixes = ["PEARL", "ACAIA", "PYXIS", "LUNAR", "PROCH", "CINCO"]

  private var central: CBCentralManager?
  private var peripheral: CBPeripheral?
  private var writeCharacteristic: CBCharacteristic?
  private var decoder = AcaiaDecoder()
  private var watch = ScaleTimerWatch()
  private var pulse: Timer?

  /// Built on first use, never at launch.
  ///
  /// iOS raises the Bluetooth prompt the moment a `CBCentralManager` exists,
  /// so building one eagerly asks for Bluetooth before the app has given any
  /// reason to want it.
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

  func choose(_ scale: FoundScale) {
    rememberedID = scale.id
    stopScanning()
    connectToRemembered()
  }

  func forget() {
    rememberedID = nil
    if let peripheral {
      central?.cancelPeripheralConnection(peripheral)
    }
    peripheral = nil
    state = .noneChosen
  }

  func send(_ command: AcaiaCommand) {
    guard let peripheral, let characteristic = writeCharacteristic else { return }
    // Ask the characteristic which kind of write it takes. Sending
    // `.withoutResponse` to one that does not support it is undefined, and this
    // scale answers by dropping the link.
    let kind: CBCharacteristicWriteType =
      characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
    peripheral.writeValue(Data(command.bytes), for: characteristic, type: kind)
  }

  private func connectToRemembered() {
    guard let central, central.state == .poweredOn, let id = rememberedID else { return }
    guard let known = central.retrievePeripherals(withIdentifiers: [id]).first else {
      state = .searching(name: "Scale")
      central.scanForPeripherals(withServices: nil)
      return
    }
    peripheral = known
    known.delegate = self
    state = .searching(name: known.name ?? "Scale")
    central.connect(known)
  }

  private func startPulse() {
    pulse?.invalidate()
    pulse = Timer.scheduledTimer(withTimeInterval: Self.heartbeat, repeats: true) { [weak self] _ in
      self?.send(.heartbeat)
    }
  }
}

extension ScaleConnection: CBCentralManagerDelegate {
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
    advertisementData _: [String: Any],
    rssi RSSI: NSNumber
  ) {
    guard let name = peripheral.name,
          Self.namePrefixes.contains(where: { name.uppercased().hasPrefix($0) })
    else { return }

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
    decoder = AcaiaDecoder()
    watch = ScaleTimerWatch()
    peripheral.discoverServices(nil)
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error _: Error?
  ) {
    pulse?.invalidate()
    weight = nil
    // Deliberately not a button event. A scale carried out of range has not
    // stopped anything, and a brew must not end because Bluetooth did.
    lastButton = nil
    writeCharacteristic = nil
    state = rememberedID == nil ? .noneChosen : .searching(name: peripheral.name ?? "Scale")
    // Reconnect on its own. A scale that was carried out of the kitchen and
    // brought back should not need the picker again. CoreBluetooth holds an
    // outstanding connect until the peripheral reappears, so this costs
    // nothing while it is away.
    if rememberedID != nil {
      central.connect(peripheral)
    }
  }
}

extension ScaleConnection: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
    for service in peripheral.services ?? [] {
      peripheral.discoverCharacteristics([write, notify, firmwareRevision], for: service)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error _: Error?
  ) {
    for characteristic in service.characteristics ?? [] {
      if characteristic.uuid == write {
        writeCharacteristic = characteristic
      }
      if characteristic.uuid == notify {
        peripheral.setNotifyValue(true, for: characteristic)
      }
      if characteristic.uuid == firmwareRevision {
        peripheral.readValue(for: characteristic)
      }
    }
  }

  /// The handshake goes here, not in characteristic discovery.
  ///
  /// Identify and subscribe are pointless until the scale can answer, and
  /// sending them mid-discovery is talking over it.
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error _: Error?
  ) {
    guard characteristic.uuid == notify, characteristic.isNotifying else { return }
    send(.identify)
    send(.subscribe)
    startPulse()
    state = .connected(name: peripheral.name ?? "Scale", battery: nil)
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error _: Error?
  ) {
    guard let value = characteristic.value else { return }
    if characteristic.uuid == firmwareRevision {
      firmware = String(data: value, encoding: .utf8)
      return
    }
    for message in decoder.append([UInt8](value)) {
      apply(message, from: peripheral)
    }
  }

  private func apply(_ message: AcaiaMessage, from peripheral: CBPeripheral) {
    switch message {
    case let .weight(grams):
      weight = grams
    case let .timer(seconds):
      scaleSeconds = seconds
      lastTimerAt = .now
      if watch.observe(seconds: seconds) {
        timerIsRunning = watch.isRunning
        timerHasPaused = watch.hasPaused
        timerStateChanges += 1
      }
    case let .button(button, grams, seconds):
      lastButton = button
      buttonCount += 1
      if let grams {
        weight = grams
      }
      if let seconds {
        scaleSeconds = seconds
      }
    case let .settings(battery, _):
      state = .connected(name: peripheral.name ?? "Scale", battery: battery)
    case .unhandled:
      break
    }
  }
}
