/// The paper the brew runs through.
///
/// A name and nothing else for now. Each paper used to carry the grind it
/// wants, as a dial number on one particular grinder, which is a size wearing
/// the wrong clothes. `DEVIL-37` gives a paper a size of its own.
public struct Filter: Equatable, Hashable, Sendable, Identifiable {
  public var name: String

  public var id: String {
    name
  }

  public init(name: String) {
    self.name = name
  }
}

public extension Filter {
  static let harioV60Natural = Filter(name: "Hario V60, Natural")
  static let cafecAbaca = Filter(name: "Cafec, Abaca")
  static let sibaristFast = Filter(name: "Sibarist, Fast")

  static let all: [Filter] = [.harioV60Natural, .cafecAbaca, .sibaristFast]
}
