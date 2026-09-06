/// The wire format the scale speaks.
///
/// Every frame opens `ef dd` and closes with two checksums: one summing the
/// even-indexed bytes of its body, one the odd. Outgoing and incoming frames
/// are not symmetric. A command carries no length byte and checksums only its
/// payload; a notification carries a length at index 3 and checksums from
/// there. That asymmetry is the scale's, not a mistake here.
public enum AcaiaFrame {
  public static let header: [UInt8] = [0xEF, 0xDD]

  /// The pair of checksums for a body, even-indexed sum then odd-indexed.
  public static func checksums(of body: [UInt8]) -> (even: UInt8, odd: UInt8) {
    var even: UInt8 = 0
    var odd: UInt8 = 0
    for (index, byte) in body.enumerated() {
      if index.isMultiple(of: 2) {
        even &+= byte
      } else {
        odd &+= byte
      }
    }
    return (even, odd)
  }

  /// Wrap a command payload: header, type, payload, checksums.
  public static func command(_ type: UInt8, _ payload: [UInt8]) -> [UInt8] {
    let sums = checksums(of: payload)
    return header + [type] + payload + [sums.even, sums.odd]
  }
}
