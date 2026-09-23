/// An ESP32 BluFi frame.
///
/// BluFi is Espressif's provisioning transport, documented in full, and the
/// ThermoMaven carries its status reports over it. None of this needed
/// working out: the vendor's own app logs under `BlufiClientImpl`.
///
/// ```text
/// [type | subtype] [frame control] [sequence] [length] [data ...]
/// ```
///
/// So a frame runs to its length plus four. `type` is the low two bits of the
/// first byte and `subtype` the rest, which is why every frame here begins
/// `4d`: type 1, subtype 19, a data frame carrying custom data.
public struct BlufiFrame: Equatable, Sendable {
  /// Frame control, one bit at a time.
  public struct Control: Equatable, Sendable {
    public var raw: UInt8
    /// BluFi's own encryption. Always off on this device, which is why the
    /// payload can be read at all.
    public var isEncrypted: Bool {
      raw & 0x01 != 0
    }

    public var hasChecksum: Bool {
      raw & 0x02 != 0
    }

    /// One piece of a larger message. The first two bytes of a fragment's
    /// data are how much content is still to come, not content themselves.
    public var isFragment: Bool {
      raw & 0x10 != 0
    }
  }

  /// Header, frame control, sequence and length.
  public static let overhead = 4

  public var type: UInt8
  public var subtype: UInt8
  public var control: Control
  public var sequence: UInt8
  public var data: [UInt8]
}

/// Reads the stream, reassembles it, and hands over whole messages.
///
/// Stateful twice over: Bluetooth delivers part of a frame or several at once,
/// and BluFi then splits a long message across frames. Feed it every packet.
public struct BlufiDecoder: Sendable {
  private var buffer: [UInt8] = []
  private var message: [UInt8] = []

  public init() {}

  /// Feed bytes in, take whole reassembled messages out.
  public mutating func append(_ bytes: [UInt8]) -> [[UInt8]] {
    buffer += bytes
    var complete: [[UInt8]] = []
    while let frame = Self.readFrame(&buffer) {
      // A fragment's first two bytes count what is still to come. They are
      // bookkeeping, and putting them in the message corrupts it.
      if frame.control.isFragment {
        message += frame.data.dropFirst(2)
      } else {
        message += frame.data
        complete.append(message)
        message = []
      }
    }
    return complete
  }

  static func readFrame(_ buffer: inout [UInt8]) -> BlufiFrame? {
    guard buffer.count >= BlufiFrame.overhead else { return nil }
    let length = Int(buffer[3])
    let end = BlufiFrame.overhead + length
    guard buffer.count >= end else { return nil }

    let head = buffer[0]
    let frame = BlufiFrame(
      type: head & 0x03,
      subtype: head >> 2,
      control: BlufiFrame.Control(raw: buffer[1]),
      sequence: buffer[2],
      data: Array(buffer[BlufiFrame.overhead ..< end])
    )
    buffer.removeFirst(end)
    return frame
  }
}
