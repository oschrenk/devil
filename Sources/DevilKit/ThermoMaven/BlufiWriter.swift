/// Splits a message into BluFi frames the base station will read.
///
/// The mirror of `BlufiDecoder`. A frame carries at most 255 bytes of data
/// because the length is one byte, and in practice the device sends 246, so
/// that is what this sends too: matching what the vendor's app does costs
/// nothing and removes a variable.
///
/// Every frame but the last sets the fragment bit, and a fragment's first two
/// bytes say how much content is still to come, itself included.
public enum BlufiWriter {
  /// Type 1, subtype 19: a data frame carrying custom data. Every frame the
  /// base station sends has this, and every frame it accepts wants it.
  public static let customData: UInt8 = 0x4D
  /// What the device uses, so this uses it.
  public static let payloadLimit = 246
  /// Direction, with the fragment bit added when one is needed.
  public static let control: UInt8 = 0x04
  public static let fragmentBit: UInt8 = 0x10

  /// The frames for one message, in order, starting at a sequence number.
  ///
  /// The sequence counts frames rather than messages and wraps at 256, which
  /// is what the device's own numbering does.
  public static func frames(for message: [UInt8], startingAt sequence: UInt8) -> [[UInt8]] {
    guard !message.isEmpty else { return [] }
    var out: [[UInt8]] = []
    var offset = 0
    var next = sequence

    while offset < message.count {
      let remaining = message.count - offset
      // Two of a fragment's bytes are its own bookkeeping, so it carries less
      // content than a whole frame does.
      let isFragment = remaining > payloadLimit
      let room = isFragment ? payloadLimit - 2 : payloadLimit
      let take = min(room, remaining)

      var data: [UInt8] = []
      if isFragment {
        data += BtProtocolPackage.pair(remaining)
      }
      data += Array(message[offset ..< (offset + take)])

      out.append(
        [customData, isFragment ? control | fragmentBit : control, next, UInt8(data.count)] + data
      )
      offset += take
      next = next &+ 1
    }
    return out
  }
}
