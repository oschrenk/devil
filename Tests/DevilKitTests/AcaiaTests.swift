@testable import DevilKit
import Testing

/// Build an event-notification frame the way the scale does, so a test can
/// name a payload instead of a hex string.
func eventFrame(_ msgType: UInt8, _ payload: [UInt8]) -> [UInt8] {
  let body = [UInt8(payload.count + 2), msgType] + payload
  let sums = AcaiaFrame.checksums(of: body)
  return AcaiaFrame.header + [12] + body + [sums.even, sums.odd]
}

func hex(_ string: String) -> [UInt8] {
  stride(from: 0, to: string.count, by: 2).map { offset in
    let start = string.index(string.startIndex, offsetBy: offset)
    let end = string.index(start, offsetBy: 2)
    return UInt8(string[start ..< end], radix: 16)!
  }
}

/// Weight of 175.9 g, and a time of 1:30.5.
let weightBody: [UInt8] = [0xDF, 0x06, 0x00, 0x00, 0x01, 0x00]
let timeBody: [UInt8] = [0x01, 0x1E, 0x05]

@Suite("Acaia commands")
struct AcaiaCommandTests {
  /// The exact bytes, because a scale that receives a wrong one says nothing
  /// rather than complaining.
  @Test("Every command encodes to its known bytes")
  func commandBytes() {
    #expect(AcaiaCommand.tare.bytes == hex("efdd04000000"))
    #expect(AcaiaCommand.startTimer.bytes == hex("efdd0d00000000"))
    #expect(AcaiaCommand.stopTimer.bytes == hex("efdd0d00020002"))
    #expect(AcaiaCommand.resetTimer.bytes == hex("efdd0d00010001"))
    #expect(AcaiaCommand.heartbeat.bytes == hex("efdd0002000200"))
  }

  /// Asserted whole rather than in slices: a wrong payload length would send a
  /// slice test out of bounds and crash instead of failing.
  @Test("Identify sends fifteen ASCII digits, which is what the newer scales expect")
  func identify() {
    #expect(AcaiaCommand.identify.bytes
      == hex("efdd0b3031323334353637383930313233349a6d"))
  }

  @Test("Subscribe asks for weight, battery, timer and buttons")
  func subscribe() {
    #expect(AcaiaCommand.subscribe.bytes == hex("efdd0c0900010102020503041506"))
  }

  @Test("Every command is framed and checksummed")
  func allAreWellFormed() {
    for command in AcaiaCommand.allCases {
      let bytes = command.bytes
      #expect(Array(bytes.prefix(2)) == AcaiaFrame.header)
      let sums = AcaiaFrame.checksums(of: Array(bytes[3 ..< (bytes.count - 2)]))
      #expect(bytes[bytes.count - 2] == sums.even)
      #expect(bytes[bytes.count - 1] == sums.odd)
    }
  }
}

@Suite("Acaia messages")
struct AcaiaMessageTests {
  /// A verbatim capture from a scale, decoding to 175.9 g.
  @Test("A real weight capture decodes")
  func realWeight() {
    var decoder = AcaiaDecoder()

    #expect(decoder.append(hex("efdd0c0c05df060000010007000002f30d")) == [.weight(grams: 175.9)])
  }

  @Test("A weight divides by its unit byte, and carries its sign")
  func weightUnits() {
    var decoder = AcaiaDecoder()
    let negative: [UInt8] = [0xDF, 0x06, 0x00, 0x00, 0x01, 0x02]

    #expect(decoder.append(eventFrame(5, [0xDF, 0x06, 0x00, 0x00, 0x02, 0x00]))
      == [.weight(grams: 17.59)])
    #expect(decoder.append(eventFrame(5, negative)) == [.weight(grams: -175.9)])
    #expect(decoder.append(eventFrame(5, [0xDF, 0x06, 0x00, 0x00, 0x00, 0x00]))
      == [.unhandled(command: 12, type: 5)])
  }

  @Test("A timer decodes to minutes, seconds and tenths")
  func timer() {
    var decoder = AcaiaDecoder()

    #expect(decoder.append(eventFrame(7, timeBody)) == [.timer(seconds: 90.5)])
  }

  @Test("A heartbeat wrapping a timer decodes to the timer")
  func heartbeat() {
    var decoder = AcaiaDecoder()

    #expect(decoder.append(eventFrame(11, [0, 0, 7] + timeBody)) == [.timer(seconds: 90.5)])
    #expect(decoder.append(eventFrame(11, [0, 0, 5] + weightBody)) == [.weight(grams: 175.9)])
  }

  /// A payload is a chain of records, so one frame can hold both.
  @Test("One frame carrying a weight and a timer decodes to both")
  func recordChain() {
    let fields = AcaiaRecords.walk([5] + weightBody + [7] + timeBody)

    #expect(fields.weight == 175.9)
    #expect(fields.time == 90.5)
  }

  /// Tag 0x0b is unexplained and two bytes wide. Step over it wrongly and
  /// every record behind it is lost.
  @Test("The walk steps over tag 0x0b by its width")
  func unknownTag() {
    let fields = AcaiaRecords.walk([8, 8, 0x0B, 0x00, 0xE0, 5] + weightBody)

    #expect(fields.key == 8)
    #expect(fields.weight == 175.9)
  }

  @Test("The buttons are told apart, which is what lets a stop differ from a reset")
  func buttons() {
    var decoder = AcaiaDecoder()

    #expect(decoder.append(eventFrame(8, [8])) == [.button(.start, grams: nil, seconds: nil)])
    #expect(decoder.append(eventFrame(8, [9])) == [.button(.reset, grams: nil, seconds: nil)])
    #expect(decoder.append(eventFrame(8, [0, 5] + weightBody))
      == [.button(.tare, grams: 175.9, seconds: nil)])
  }

  /// Verbatim captures from a 2021-generation scale, which is what a Pearl S
  /// is. A start press carries nothing; a stop carries a weight then a time.
  @Test("Real 2021-generation button captures decode")
  func realButtons() {
    var decoder = AcaiaDecoder()

    #expect(decoder.append(eventFrame(8, hex("08"))) == [.button(.start, grams: nil, seconds: nil)])
    #expect(decoder.append(eventFrame(8, hex("09"))) == [.button(.reset, grams: nil, seconds: nil)])
    #expect(decoder.append(eventFrame(8, hex("0a0500000000010107000a08")))
      == [.button(.stop, grams: 0, seconds: 10.8)])
  }

  @Test("A real settings capture gives the battery")
  func settings() {
    var decoder = AcaiaDecoder()

    #expect(decoder.append(hex("efdd08095d020201000101000d60"))
      == [.settings(battery: 93, isGrams: true)])
  }
}

@Suite("Acaia stream")
struct AcaiaStreamTests {
  /// Bluetooth delivers whatever arrived, so every split has to survive.
  @Test("A frame split across two packets decodes once both arrive")
  func splitFrame() {
    let frame = hex("efdd0c0c05df060000010007000002f30d")

    for split in 1 ..< frame.count {
      var decoder = AcaiaDecoder()
      #expect(decoder.append(Array(frame.prefix(split))).isEmpty)
      #expect(decoder.append(Array(frame.dropFirst(split))) == [.weight(grams: 175.9)])
    }
  }

  @Test("Two frames in one packet both decode")
  func concatenated() {
    var decoder = AcaiaDecoder()
    let packet = hex("efdd0c0c05df060000010007000002f30d") + eventFrame(7, timeBody)

    #expect(decoder.append(packet) == [.weight(grams: 175.9), .timer(seconds: 90.5)])
  }

  @Test("Noise before a frame is skipped rather than swallowing it")
  func leadingNoise() {
    var decoder = AcaiaDecoder()

    #expect(decoder.append([0x00, 0x01, 0x02] + hex("efdd0c0c05df060000010007000002f30d"))
      == [.weight(grams: 175.9)])
  }

  /// A frame that fails its own checksum goes whole. Resynchronising inside it
  /// would decode its own bytes as a new frame.
  @Test("A bad checksum drops the frame and the stream carries on")
  func badChecksum() {
    var decoder = AcaiaDecoder()
    var frame = hex("efdd0c0c05df060000010007000002f30d")
    frame[frame.count - 1] ^= 0x01

    #expect(decoder.append(frame).isEmpty)
    #expect(decoder.append(eventFrame(7, timeBody)) == [.timer(seconds: 90.5)])
  }

  @Test("Bytes with no header in them are dropped rather than held for ever")
  func noise() {
    var decoder = AcaiaDecoder()

    #expect(decoder.append([0x01, 0x02, 0x03, 0x04]).isEmpty)
    #expect(decoder.append(eventFrame(7, timeBody)) == [.timer(seconds: 90.5)])
  }
}
