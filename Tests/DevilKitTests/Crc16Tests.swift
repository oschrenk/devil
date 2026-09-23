@testable import DevilKit
import Testing

@Suite("CRC-16")
struct Crc16Tests {
  /// The published check value for CRC-16/XMODEM. If this passes, the
  /// polynomial and the starting value are right, and the table in the
  /// vendor's app needs no copying.
  @Test("The standard check value comes out")
  func standard() {
    #expect(Crc16.xmodem(Array("123456789".utf8)) == 0x31C3)
  }

  /// Low byte first, which is how it sits in a message and the opposite of
  /// how it reads as a number.
  @Test("It goes out low byte first")
  func order() {
    #expect(Crc16.bytes(Array("123456789".utf8)) == [0xC3, 0x31])
  }

  @Test("Nothing checksums to zero")
  func empty() {
    #expect(Crc16.xmodem([]) == 0)
  }
}
