import Foundation
import libzstd

/// Zstandard, as much of it as this app needs.
///
/// The ThermoMaven compresses its status reports, and Apple's Compression
/// framework has Brotli, LZ4, LZFSE, LZMA and zlib but not this. So the C
/// library comes in from upstream and this wraps the one call that matters.
public enum Zstd {
  /// Squeeze a message down, for sending.
  ///
  /// The device compresses everything it sends, and expects the same back.
  /// Level three is zstd's own default, and the vendor's app does not appear
  /// to ask for anything else.
  public static func compress(_ raw: [UInt8]) -> [UInt8]? {
    guard !raw.isEmpty else { return nil }
    let capacity = ZSTD_compressBound(raw.count)
    var out = [UInt8](repeating: 0, count: capacity)

    let written = out.withUnsafeMutableBytes { destination in
      raw.withUnsafeBytes { source in
        ZSTD_compress(destination.baseAddress, capacity, source.baseAddress, raw.count, 3)
      }
    }
    guard ZSTD_isError(written) == 0 else { return nil }
    return Array(out.prefix(written))
  }

  /// Expand a frame whose size the sender already told us.
  ///
  /// The size comes from the message rather than from the frame, because the
  /// device states it and a mismatch is how a corrupt message announces
  /// itself. `nil` on any error, including a size that disagrees.
  public static func decompress(_ body: [UInt8], expecting expanded: Int) -> [UInt8]? {
    guard !body.isEmpty, expanded > 0 else { return nil }
    var out = [UInt8](repeating: 0, count: expanded)

    let written = out.withUnsafeMutableBytes { destination in
      body.withUnsafeBytes { source in
        ZSTD_decompress(
          destination.baseAddress, expanded,
          source.baseAddress, body.count
        )
      }
    }
    guard ZSTD_isError(written) == 0, written == expanded else { return nil }
    return out
  }
}
