/// The message a ThermoMaven base station sends, once its BluFi fragments are
/// back together.
///
/// Auros call this `BtProtocolPackage`, which is the name their own app uses.
///
/// ```text
/// aa aa | compressed | uncompressed | body ... | crc | crc
///   0 1     2   3          4   5       6 ...
/// ```
///
/// Both lengths are little-endian. The whole message runs to the compressed
/// length plus ten, which is the check their app makes first. The body is
/// Zstandard, and `DevilProbe` decompresses it into JSON.
///
/// Nothing here is encrypted. The two lengths differ because one counts the
/// compressed body and the other what it expands to.
public struct BtProtocolPackage: Equatable, Sendable {
  public static let header: [UInt8] = [0xAA, 0xAA]
  /// Header, two lengths and two checksums. Everything but the body.
  public static let overhead = 10

  /// The Zstandard body, still compressed.
  public var body: [UInt8]
  /// What the body expands to, as the device states it.
  public var expandedCount: Int
  public var packageCrc: [UInt8]
  public var messageCrc: [UInt8]

  public init(body: [UInt8], expandedCount: Int, packageCrc: [UInt8], messageCrc: [UInt8]) {
    self.body = body
    self.expandedCount = expandedCount
    self.packageCrc = packageCrc
    self.messageCrc = messageCrc
  }

  /// Reads a reassembled message, or `nil` when it is not one.
  public static func parse(_ bytes: [UInt8]) -> BtProtocolPackage? {
    guard bytes.count > overhead,
          bytes[0] == header[0], bytes[1] == header[1]
    else { return nil }

    let compressed = Int(bytes[2]) | Int(bytes[3]) << 8
    let expanded = Int(bytes[4]) | Int(bytes[5]) << 8
    guard bytes.count == compressed + overhead else { return nil }

    return BtProtocolPackage(
      body: Array(bytes[6 ..< (6 + compressed)]),
      expandedCount: expanded,
      packageCrc: Array(bytes[(6 + compressed) ..< (8 + compressed)]),
      messageCrc: Array(bytes[(8 + compressed)...])
    )
  }
}
