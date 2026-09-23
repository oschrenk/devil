@testable import DevilKit
@testable import DevilProbe
import Foundation
import Testing

@Suite("Asking the base station")
struct ProbeCommandTests {
  /// The whole writer, checked by the reader. If a built frame comes back as
  /// the JSON that went in, every layer agrees with itself.
  @Test("A built command reads back as the command that was built")
  func roundTrip() throws {
    let command = ProbeCommand.statusRequest
    let frames = try #require(command.frames(id: "abc123", sequence: 7, from: 0))

    var decoder = BlufiDecoder()
    var messages: [[UInt8]] = []
    for frame in frames {
      messages += decoder.append(frame)
    }
    #expect(messages.count == 1)

    let package = try #require(BtProtocolPackage.parse(messages[0]))
    let raw = try #require(Zstd.decompress(package.body, expecting: package.expandedCount))
    let json = try #require(String(bytes: raw, encoding: .utf8))
    #expect(json.contains("\"cmdType\":\"device:status:request\""))
    #expect(json.contains("\"cmdSeqNo\":7"))
  }

  /// The checksum is the difference between reading and writing, and a wrong
  /// one is indistinguishable from silence.
  @Test("A built message passes its own checksum")
  func checksum() throws {
    let frames = try #require(ProbeCommand.applyTrust.frames(id: "x", sequence: 1, from: 0))
    var decoder = BlufiDecoder()
    let message = try #require(frames.flatMap { decoder.append($0) }.first)
    let package = try #require(BtProtocolPackage.parse(message))
    #expect(package.packageCrcMatches)
  }

  /// A short command is one frame, and the fragment bit stays off.
  @Test("A short command fits one frame")
  func single() throws {
    let frames = try #require(ProbeCommand.statusRequest.frames(id: "x", sequence: 1, from: 9))
    #expect(frames.count == 1)
    #expect(frames[0][0] == BlufiWriter.customData)
    #expect(frames[0][1] & BlufiWriter.fragmentBit == 0)
    #expect(frames[0][2] == 9)
    #expect(frames[0].count == Int(frames[0][3]) + 4)
  }

  /// And a long one splits, with the bit set on all but the last.
  @Test("A long message fragments, and only the last frame is whole")
  func fragments() {
    let long = [UInt8](repeating: 0x41, count: 600)
    let frames = BlufiWriter.frames(for: long, startingAt: 0)
    #expect(frames.count == 3)
    #expect(frames.dropLast().allSatisfy { $0[1] & BlufiWriter.fragmentBit != 0 })
    #expect((frames.last?[1] ?? 0) & BlufiWriter.fragmentBit == 0)
    // Reassembling gives back exactly what went in.
    var decoder = BlufiDecoder()
    #expect(frames.flatMap { decoder.append($0) }.first == long)
  }

  /// Sequence numbers count frames and wrap, as the device's own do.
  @Test("The sequence counts frames and wraps at 256")
  func sequence() {
    let frames = BlufiWriter.frames(for: [UInt8](repeating: 1, count: 600), startingAt: 254)
    #expect(frames.map { $0[2] } == [254, 255, 0])
  }

  /// Nothing here may change the device.
  @Test("Only read-only commands exist")
  func readOnly() {
    let dangerous = ["Config:WIFI", "Unpair", "unbind", "modify"]
    for command in ProbeCommand.allCases {
      #expect(!dangerous.contains { command.rawValue.contains($0) })
    }
  }
}

@Suite("Receipts")
struct ReceiptTests {
  private func decode(_ json: String) throws -> ProbeReport {
    try JSONDecoder().decode(ProbeReport.self, from: Data(json.utf8))
  }

  /// The refusal that cost an evening. The old model required readings, so a
  /// receipt threw during decoding and looked exactly like silence.
  @Test("A refusal decodes, and says what it refused and for whom")
  func refusal() throws {
    let report = try decode(#"""
    {"cmdType": "device:cmd:receipt", "userId": "100000000000000001",
      "cmdData": {"cmdType": "device:status:request",
      "executeResult": "failure", "errorCode": 0, "cmdError": 6}}
    """#)
    #expect(report.isReceipt)
    #expect(report.refused)
    #expect(report.cmdData.cmdError == 6)
    #expect(report.cmdData.probes == nil)
    // The account, which is what trust needs and what Devil cannot know.
    #expect(report.userId == "100000000000000001")
  }

  /// Trust carries six fields. The others carry none, and sending them would
  /// be inventing a shape the device never asked for.
  @Test("Trust names the account, and other commands send nothing")
  func trustPayload() {
    let trust = ProbeCommand.applyTrust
      .json(id: "a", sequence: 1, userId: "123", milliseconds: 1_790_200_155_000)
    #expect(trust.contains("\"userId\":\"123\""))
    #expect(trust.contains("\"mode\":\"direct\""))
    #expect(trust.contains("\"deviceModel\":\"WT11\""))
    // A number, not a string, which is how their own builder writes it.
    #expect(trust.contains("\"cmdSeqNo\":1"))
    #expect(trust.contains("\"serverTime\":1790200155000"))
    #expect(trust.contains("\"serverTimeSecond\":1790200155"))
    #expect(trust.contains("\"deviceType\":\"WT11\""))
    // Absent rather than empty: their builder passes null.
    #expect(!trust.contains("protocol"))
    let status = ProbeCommand.statusRequest
      .json(id: "a", sequence: 1, userId: "123", milliseconds: 1_790_200_155_000)
    #expect(status.contains("\"cmdData\":{}"))
    #expect(!status.contains("userId"))
  }
}
