/// The chain of fields inside a notification.
///
/// A payload is not one value. It is a run of `[tag][body]` records to the end
/// of the frame, so a single stop press arrives carrying both a weight and a
/// time. Each tag has a fixed width, and an unknown one makes everything behind
/// it unreadable, so the walk stops rather than guessing at offsets.
enum AcaiaRecords {
  struct Fields {
    var key: UInt8?
    var weight: Double?
    var time: Double?
  }

  static let weightTag: UInt8 = 5
  static let batteryTag: UInt8 = 6
  static let timeTag: UInt8 = 7
  static let buttonTag: UInt8 = 8
  /// Unexplained, and always `00 e0`. Its width has to be right or every record
  /// behind it is lost.
  static let unknownTag: UInt8 = 11

  static let widths: [UInt8: Int] = [
    weightTag: 6,
    batteryTag: 1,
    timeTag: 3,
    unknownTag: 2,
  ]

  /// Grams. Two little-endian bytes over a divisor, with the sign in a flag.
  static func weight(_ body: [UInt8]) -> Double? {
    guard body.count >= 6 else { return nil }
    let raw = Double(Int(body[1]) << 8 | Int(body[0]))
    let divisor: Double
    switch body[4] {
    case 1: divisor = 10
    case 2: divisor = 100
    case 3: divisor = 1000
    case 4: divisor = 10000
    default: return nil
    }
    let value = raw / divisor
    return body[5] & 0x02 != 0 ? -value : value
  }

  /// Seconds. Minutes, seconds and tenths, in three bytes.
  static func time(_ body: [UInt8]) -> Double? {
    guard body.count >= 3 else { return nil }
    return Double(body[0]) * 60 + Double(body[1]) + Double(body[2]) / 10
  }

  static func walk(_ payload: [UInt8]) -> Fields {
    var fields = Fields()
    var index = 0
    while index < payload.count {
      let tag = payload[index]
      if tag == buttonTag {
        guard index + 2 <= payload.count else { break }
        fields.key = payload[index + 1]
        index += 2
        continue
      }
      guard let width = widths[tag], index + 1 + width <= payload.count else { break }
      let body = Array(payload[(index + 1) ..< (index + 1 + width)])
      if tag == weightTag {
        fields.weight = weight(body)
      } else if tag == timeTag {
        fields.time = time(body)
      }
      index += 1 + width
    }
    return fields
  }
}
