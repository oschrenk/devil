@testable import DevilKit
import Testing

@Suite("Format")
struct FormatTests {
  @Test("A pour rate always carries one decimal")
  func flow() {
    #expect(Format.flow(4.25) == "4.3 g/s")
    #expect(Format.flow(5) == "5.0 g/s")
    #expect(Format.flow(0) == "0.0 g/s")
    #expect(Format.flow(10.04) == "10.0 g/s")
  }

  /// The server has been lifted off, and the weight really is falling.
  @Test("A falling weight keeps its sign")
  func negativeFlow() {
    #expect(Format.flow(-3.2) == "-3.2 g/s")
    #expect(Format.flow(-0.4) == "-0.4 g/s")
  }
}
