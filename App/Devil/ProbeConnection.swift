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
  /// Where the account is kept between launches. Handed in rather than read
  /// here, so the settings screen and the radio agree on one copy.
  var defaults: BrewDefaults?

  private(set) var state: ProbeState = .noneChosen
  private(set) var found: [FoundScale] = []
  /// The last report, whole. `nil` until three frames have arrived.
  private(set) var probe: ProbeReport.Probe?
  /// How many reports have decoded. What a view watches, because two
  /// identical readings are still two readings.
  private(set) var reports = 0
  /// Whether `ff01` turned up. Without it nothing can be asked, and the row
  /// would wait for ever with no sign of why.
  private(set) var canWrite = false
  /// Frames written, and frames received. Silence has several causes and
  /// these separate them: nothing sent is a different fault from nothing
  /// answered.
  private(set) var framesSent = 0
  private(set) var framesHeard = 0
  /// Learned from a receipt rather than configured. The base station names
  /// the account in every reply, including the ones refusing a command.
  /// The account in force. The stored one until the base station corrects it,
  /// which it does by naming its own in a receipt.
  var userId: String? {
    get { remembered ?? learned }
    set { learned = newValue }
  }

  private var learned: String?

  private var remembered: String? {
    let stored = defaults?.probeAccount ?? ""
    return stored.isEmpty ? nil : stored
  }

  /// The last refusal's code, so a silent row can say why it is silent.
  private(set) var refusal: Int?

  private var rememberedID: UUID? {
    get { UserDefaults.standard.string(forKey: Self.key).flatMap(UUID.init(uuidString:)) }
    set { UserDefaults.standard.set(newValue?.uuidString, forKey: Self.key) }
  }

  private static let key = "probe.peripheral"
  // Instance rather than static: CBUUID is not Sendable.
  private let service = CBUUID(string: "0000FFFF-0000-1000-8000-00805F9B34FB")
  private let notify = CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")
  private let write = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")

  private var central: CBCentralManager?
  private var peripheral: CBPeripheral?
  private var blufi = BlufiDecoder()
  private var writePort: CBCharacteristic?
  /// Counts frames, not messages, because BluFi's sequence does.
  private var outgoing: UInt8 = 0
  private var asked = 0

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

  /// Asks the base station to talk.
  ///
  /// It streams because something requests it. Their app sends
  /// `BT:apply:trust` on connect and then its requests, and Devil used to
  /// only listen, so nothing arrived unless that app was open doing the
  /// asking.
  ///
  /// Trust first, then the status request, with a moment between them. The
  /// device replies to trust with a receipt, and asking before it has
  /// answered is talking over it.
  func ask() {
    send(.applyTrust)
    Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
      self?.send(.statusRequest)
    }
  }

  func send(_ command: ProbeCommand) {
    guard let peripheral, let characteristic = writePort else { return }
    asked += 1
    guard let frames = command.frames(
      id: ProbeCommand.newID(), sequence: asked, from: outgoing, userId: userId
    ) else { return }

    let kind: CBCharacteristicWriteType =
      characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
    for frame in frames {
      peripheral.writeValue(Data(frame), for: characteristic, type: kind)
      outgoing = outgoing &+ 1
      framesSent += 1
    }
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
    writePort = nil
    canWrite = false
    outgoing = 0
    refusal = nil
    framesSent = 0
    framesHeard = 0
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
      peripheral.discoverCharacteristics([notify, write], for: found)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error _: Error?
  ) {
    for characteristic in service.characteristics ?? [] {
      if characteristic.uuid == write {
        writePort = characteristic
        canWrite = true
      }
      if characteristic.uuid == notify {
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error _: Error?
  ) {
    guard characteristic.uuid == notify, characteristic.isNotifying else { return }
    state = .connected(name: peripheral.name ?? "Probe")
    // Asking goes here rather than in characteristic discovery. A request
    // sent before the subscription is live has nowhere to be answered.
    ask()
  }

  func peripheral(
    _: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error _: Error?
  ) {
    guard let value = characteristic.value else { return }
    framesHeard += 1
    for message in blufi.append([UInt8](value)) {
      guard let report = ProbeReport.decode(message: message) else { continue }
      if let found = report.cmdData.probes?.first {
        probe = found
        reports += 1
        refusal = nil
        continue
      }
      guard report.isReceipt else { continue }
      refusal = report.refused ? report.cmdData.cmdError : nil
      // The first refusal is the useful one: it names the account, and trust
      // needs the account. Ask again now that we know it.
      if let named = report.userId, named != userId {
        userId = named
        // Kept, so the next connection asks properly the first time rather
        // than being refused once to find out who it is talking to.
        defaults?.probeAccount = named
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
          self?.ask()
        }
      }
    }
  }
}
