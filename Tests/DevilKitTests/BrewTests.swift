@testable import DevilKit
import Testing

@Test func brewCarriesItsName() {
  #expect(Brew.name == "Devil")
  #expect(Brew.brewer == "Hario Switch")
}
