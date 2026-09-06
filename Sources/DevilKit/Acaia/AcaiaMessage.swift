/// A button on the scale.
public enum AcaiaButton: UInt8, Equatable, Sendable {
  case tare = 0
  case start = 8
  case reset = 9
  case stop = 10
}

/// Something the scale said.
public enum AcaiaMessage: Equatable, Sendable {
  case weight(grams: Double)
  case timer(seconds: Double)
  /// A press, with whatever the scale attached to it. A stop usually carries
  /// both a weight and a time; a start on newer firmware carries neither.
  case button(AcaiaButton, grams: Double?, seconds: Double?)
  case settings(battery: Int, isGrams: Bool)
  /// A frame that decoded cleanly and means nothing to this app.
  case other
}

/// Reads the scale's stream.
///
/// Stateful on purpose. Bluetooth hands over whatever arrived, which is a
/// frame, or half of one, or three at once. Feed it every packet and take the
/// messages it can complete; it keeps the rest until the remainder turns up.
public struct AcaiaDecoder: Sendable {
  private var buffer: [UInt8] = []

  public init() {}

  /// Feed bytes in, take whole messages out.
  public mutating func append(_ bytes: [UInt8]) -> [AcaiaMessage] {
    buffer += bytes
    var messages: [AcaiaMessage] = []
    while let (message, consumed) = Self.readFrame(buffer) {
      buffer.removeFirst(consumed)
      if let message {
        messages.append(message)
      }
    }
    // A buffer with no header in it is noise, not a fragment, and dropping it
    // stops one corrupt byte holding every later frame hostage. A trailing
    // `ef` is the exception: it is half a header whose other half has not
    // arrived, and discarding it loses the frame behind it.
    if !buffer.isEmpty, Self.headerIndex(buffer) == nil {
      let danglingHeader = buffer.last == AcaiaFrame.header[0]
      buffer = danglingHeader ? [AcaiaFrame.header[0]] : []
    }
    return messages
  }

  static func headerIndex(_ bytes: [UInt8]) -> Int? {
    guard bytes.count >= 2 else { return nil }
    let first = AcaiaFrame.header[0]
    let second = AcaiaFrame.header[1]
    for index in 0 ... (bytes.count - 2) where bytes[index] == first && bytes[index + 1] == second {
      return index
    }
    return nil
  }

  /// One frame, or `nil` while the buffer holds less than a whole one.
  ///
  /// The count returned covers the bytes before the header too, so leading
  /// noise leaves with the frame it preceded.
  static func readFrame(_ bytes: [UInt8]) -> (message: AcaiaMessage?, consumed: Int)? {
    guard let start = headerIndex(bytes), bytes.count - start >= 6 else { return nil }
    // Frame: header, command, length, payload, two checksums.
    let end = start + Int(bytes[start + 3]) + 5
    guard end <= bytes.count else { return nil }

    let body = Array(bytes[(start + 3) ..< (end - 2)])
    let sums = AcaiaFrame.checksums(of: body)
    guard bytes[end - 2] == sums.even, bytes[end - 1] == sums.odd else {
      // A frame that fails its own checksum is discarded whole. Keeping it
      // would resynchronise on a byte inside it and decode noise as data.
      return (nil, end - start)
    }

    let command = bytes[start + 2]
    let payload = Array(bytes[(start + 5) ..< (end - 2)])
    switch command {
    case 12 where bytes[start + 3] >= 2:
      return (message(type: bytes[start + 4], payload: payload), end - start)
    case 8:
      return (settings(Array(bytes[(start + 3) ..< (end - 2)])), end - start)
    default:
      return (.other, end - start)
    }
  }

  static func settings(_ body: [UInt8]) -> AcaiaMessage {
    guard body.count >= 3 else { return .other }
    return .settings(battery: Int(body[1] & 0x7F), isGrams: body[2] == 2)
  }

  static func message(type: UInt8, payload: [UInt8]) -> AcaiaMessage {
    switch type {
    case 5:
      return AcaiaRecords.weight(payload).map { AcaiaMessage.weight(grams: $0) } ?? .other
    case 7:
      return AcaiaRecords.time(payload).map { AcaiaMessage.timer(seconds: $0) } ?? .other
    case 8:
      let records = AcaiaRecords.walk([8] + payload)
      guard let key = records.key, let button = AcaiaButton(rawValue: key) else { return .other }
      return .button(button, grams: records.weight, seconds: records.time)
    case 11:
      // A heartbeat wraps one record, three bytes in.
      guard payload.count > 3 else { return .other }
      return message(type: payload[2], payload: Array(payload.dropFirst(3)))
    default:
      return .other
    }
  }
}
