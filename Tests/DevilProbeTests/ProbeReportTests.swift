@testable import DevilKit
@testable import DevilProbe
import Testing

/// One real message, captured 2026-09-22 at 20:39:04 with the probe resting on
/// a counter. It arrived as three BluFi frames and is stored here reassembled,
/// from the `aa aa` to the last checksum.
///
/// The vendor's own app showed 25.84, 25.94, 25.96, 25.94 and 26.00 degrees
/// Celsius at that moment, with ambient 25.9.
let captured =
  "aaaaf9013a0328b52ffd603a027d0f0006e36624206dac032b4e5b709810a71d5185f055e455c2377840" +
  "05ffef13b6c0f70c0035401000af5c005d005d0007d3311fbe9c07cf158d09344ab62b84e57b23f475ae" +
  "93d63efc4323d4f4f108f87863c0b53db1855475e3a5606b0c85c3f304c1788e73f82e68e0474ad1d793" +
  "c8402fbe9648e6250ed99ca340114b09c5a4418be3c3cb0129458f08b6bad1f22431c356d117630d9e6f" +
  "bccfa34e866ef0b6692f9e10789484e31296702d40a16018281cbe3e1c4d07968f5880a7186a3b7d7165" +
  "2ffc633a6a2fa6632a5011f275c86de8465c6b475f873c26e4f02c55b41dbedc02003f292a774d3a8535" +
  "ae898ea1c738d79ac36198c4399231ecb1c3cb5921307447558dd2e159364123c29e6b4c49d14683cbd4" +
  "57a3ad6525cb59cb626b5980673a6fe5c8b2c17d8807ed35b7f284a4444379cd4ada6b167bcd42641bbf" +
  "d86be03991331487a71df56d3b491b5b41dbdedadae16b4fca72c234c5af3396348bd22c4b6b96e73887" +
  "512c53d5d7b2b4a634e6340d5ed68ef861693256a411a1b4aa92eb8c121f34edc147fc30742f68bc7dbf" +
  "0e7f2b4fbab8365eea2b1e003e8d387ded214e844b42f2a45aa699c1f7055bbf4da8bacdd74d2b6d48dc" +
  "89859faaed0ab5e3e735a29e01c22dbb8c9b73b8ee4d20f312c6e2c21c5638cd269a5036d830cfb289ba" +
  "35a1065e1ae61e1c7b2cd6"

func bytes(_ string: String) -> [UInt8] {
  stride(from: 0, to: string.count, by: 2).map { offset in
    let start = string.index(string.startIndex, offsetBy: offset)
    let end = string.index(start, offsetBy: 2)
    return UInt8(string[start ..< end], radix: 16)!
  }
}

@Suite("ThermoMaven report")
struct ProbeReportTests {
  /// The whole chain, on real bytes. If this passes, the protocol is right.
  @Test("A captured message decodes to the temperatures the vendor's app showed")
  func endToEnd() throws {
    let report = try #require(ProbeReport.decode(message: bytes(captured)))
    #expect(report.cmdType == "WT11:status:report")

    let probe = try #require(report.cmdData.probes.first)
    // Tenths of a degree Fahrenheit, tip first.
    #expect(probe.curTemperature == 780)
    #expect(probe.areaTemperature == [780, 781, 781, 782, 783])
    #expect(probe.curAmbientTemperature == 781)
  }

  /// The units are the trap. 78.0 Fahrenheit is 25.6 Celsius, and the app
  /// showed 25.84 a few seconds either side of this message.
  @Test("Tenths of Fahrenheit convert to what the app displayed")
  func units() throws {
    let probe = try #require(ProbeReport.decode(message: bytes(captured))?.cmdData.probes.first)
    #expect(abs(probe.tipCelsius - 25.6) < 0.1)
    #expect(abs(probe.ambientCelsius - 25.6) < 0.1)
    #expect(probe.zonesCelsius.count == 5)
    // 1580 tenths of Fahrenheit is the 70 degree target the app showed.
    #expect(abs(ProbeReport.celsius(tenthsFahrenheit: 1580) - 70) < 0.01)
  }

  @Test("The message states its own lengths, and both are used")
  func framing() throws {
    let package = try #require(BtProtocolPackage.parse(bytes(captured)))
    #expect(package.body.count == 505)
    #expect(package.expandedCount == 826)
    // The zstd magic, which is what the six constant bytes turned out to be.
    #expect(Array(package.body.prefix(4)) == [0x28, 0xB5, 0x2F, 0xFD])
  }

  /// A truncated or mistyped message must not half-decode.
  @Test("A message that disagrees with its own length yields nothing")
  func mismatch() {
    var short = bytes(captured)
    short.removeLast()
    #expect(BtProtocolPackage.parse(short) == nil)
    #expect(ProbeReport.decode(message: short) == nil)
    #expect(ProbeReport.decode(message: []) == nil)
    #expect(ProbeReport.decode(message: bytes("aaaa0100")) == nil)
  }

  /// A body whose content is not what the header claims must fail rather than
  /// return a short answer.
  @Test("A corrupted body fails instead of decoding partially")
  func corrupted() {
    var damaged = bytes(captured)
    damaged[300] ^= 0xFF
    #expect(ProbeReport.decode(message: damaged) == nil)
  }
}
