@testable import DevilKit
import Testing

/// The three frames a ThermoMaven sent at 20:39:04 on 2026-09-22, carrying one
/// status report. Two fragments at the connection's maximum size, then a short
/// one that ends the message.
let blufiFrames = [
  "4d1435f60302aaaaf9013a0328b52ffd603a027d0f0006e36624206dac032b4e5b709810a71d5185f055" +
    "e455c237784005ffef13b6c0f70c0035401000af5c005d005d0007d3311fbe9c07cf158d09344ab62b84" +
    "e57b23f475ae93d63efc4323d4f4f108f87863c0b53db1855475e3a5606b0c85c3f304c1788e73f82e68" +
    "e0474ad1d793c8402fbe9648e6250ed99ca340114b09c5a4418be3c3cb0129458f08b6bad1f22431c356" +
    "d117630d9e6fbccfa34e866ef0b6692f9e10789484e31296702d40a16018281cbe3e1c4d07968f5880a7" +
    "186a3b7d71652ffc633a6a2fa6632a5011f275c86de8465c6b475f873c26e4f02c55b41dbedc0200",
  "4d1436f60f013f292a774d3a8535ae898ea1c738d79ac36198c4399231ecb1c3cb5921307447558dd2e1" +
    "59364123c29e6b4c49d14683cbd457a3ad6525cb59cb626b5980673a6fe5c8b2c17d8807ed35b7f284a4" +
    "444379cd4ada6b167bcd42641bbfd86be03991331487a71df56d3b491b5b41dbdedadae16b4fca72c234" +
    "c5af3396348bd22c4b6b96e73887512c53d5d7b2b4a634e6340d5ed68ef861693256a411a1b4aa92eb8c" +
    "121f34edc147fc30742f68bc7dbf0e7f2b4fbab8365eea2b1e003e8d387ded214e844b42f2a45aa699c1" +
    "f7055bbf4da8bacdd74d2b6d48dc89859faaed0ab5e3e735a29e01c22dbb8c9b73b8ee4d20f312c6",
  "4d04371be2c21c5638cd269a5036d830cfb289ba35a1065e1ae61e1c7b2cd6",
]

@Suite("BluFi framing")
struct BlufiTests {
  /// The header the vendor's app reads, and the reason a frame is its length
  /// plus four.
  @Test("A frame states its type, its control bits and its length")
  func header() throws {
    var buffer = hex(blufiFrames[0])
    let frame = try #require(BlufiDecoder.readFrame(&buffer))
    #expect(frame.type == 1)
    #expect(frame.subtype == 19)
    #expect(frame.sequence == 53)
    #expect(frame.data.count == 0xF6)
    #expect(buffer.isEmpty)
    // The two that decide how to read the rest.
    #expect(frame.control.isFragment)
    #expect(!frame.control.isEncrypted)
  }

  /// The last frame ends the message rather than continuing it.
  @Test("The closing frame is not a fragment")
  func closing() throws {
    var buffer = hex(blufiFrames[2])
    let frame = try #require(BlufiDecoder.readFrame(&buffer))
    #expect(!frame.control.isFragment)
    #expect(frame.data.count == 27)
  }

  /// Three frames, one message. The two bookkeeping bytes on each fragment
  /// must not reach it: with them the message is four bytes too long and
  /// nothing downstream parses.
  @Test("Three frames reassemble into one message")
  func reassembly() {
    var decoder = BlufiDecoder()
    var messages: [[UInt8]] = []
    for frame in blufiFrames {
      messages += decoder.append(hex(frame))
    }
    #expect(messages.count == 1)
    #expect(messages[0].count == 515)
    #expect(Array(messages[0].prefix(2)) == [0xAA, 0xAA])
  }

  /// Bluetooth delivers whatever arrived, so a frame can turn up in pieces.
  @Test("A frame split across packets waits for the rest")
  func split() {
    var decoder = BlufiDecoder()
    let all = blufiFrames.flatMap(hex)
    #expect(decoder.append(Array(all[..<100])).isEmpty)
    #expect(decoder.append(Array(all[100 ..< 400])).isEmpty)
    #expect(decoder.append(Array(all[400...])).count == 1)
  }

  /// And several at once.
  @Test("Three frames in one packet still make one message")
  func concatenated() {
    var decoder = BlufiDecoder()
    #expect(decoder.append(blufiFrames.flatMap(hex)).count == 1)
  }
}
