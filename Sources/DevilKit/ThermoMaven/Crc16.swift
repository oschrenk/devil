/// CRC-16/XMODEM, which is what a ThermoMaven message checks itself with.
///
/// Auros ship the table in their app. It starts `0, 4129, 8258, 12387`, which
/// is polynomial `0x1021`, so the table is standard and computing it costs
/// less than carrying 256 constants.
///
/// The result goes out low byte first. Reading a message needs none of this,
/// and `DEVIL-46` skipped it. Writing one needs it exactly right, because a
/// wrong checksum and silence look the same from here.
public enum Crc16 {
  public static func xmodem(_ bytes: [UInt8]) -> UInt16 {
    var crc: UInt16 = 0
    for byte in bytes {
      crc ^= UInt16(byte) << 8
      for _ in 0 ..< 8 {
        crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1
      }
    }
    return crc
  }

  /// The two bytes as they sit in a message, low first.
  public static func bytes(_ input: [UInt8]) -> [UInt8] {
    let crc = xmodem(input)
    return [UInt8(crc & 0xFF), UInt8(crc >> 8)]
  }
}
