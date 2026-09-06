/// The fields you type, in the order the vault's own template lists them.
///
/// Blank when a brew is written. They are filled in over the days that follow,
/// which is why nothing here is a number: what goes in is prose, and a log
/// that refuses a half-remembered note is a log nobody fills in.
public struct BrewNotes: Equatable, Sendable {
  public var beans: String
  public var waterRecipe: String
  public var totalDissolvedSolids: String
  public var concentration: String
  public var aroma: String
  public var flavour: String
  public var aftertaste: String
  public var acidity: String
  public var sweetness: String
  public var bitterness: String
  public var texture: String
  public var afterfeel: String
  public var balance: String

  /// Everything starts empty, including the two that name a vault tag. A file
  /// states what the app knows, and a bare `#beans/` is not knowledge. The
  /// editor is where the tag belongs, and that arrives with the screen that
  /// takes these fields.
  public init(
    beans: String = "",
    waterRecipe: String = "",
    totalDissolvedSolids: String = "",
    concentration: String = "",
    aroma: String = "",
    flavour: String = "",
    aftertaste: String = "",
    acidity: String = "",
    sweetness: String = "",
    bitterness: String = "",
    texture: String = "",
    afterfeel: String = "",
    balance: String = ""
  ) {
    self.beans = beans
    self.waterRecipe = waterRecipe
    self.totalDissolvedSolids = totalDissolvedSolids
    self.concentration = concentration
    self.aroma = aroma
    self.flavour = flavour
    self.aftertaste = aftertaste
    self.acidity = acidity
    self.sweetness = sweetness
    self.bitterness = bitterness
    self.texture = texture
    self.afterfeel = afterfeel
    self.balance = balance
  }

  /// The label each field answers to in the file.
  ///
  /// One table drives both writing and reading, so a label cannot be renamed
  /// on one side alone and quietly stop parsing.
  /// Computed rather than stored, because a key path is not `Sendable` and a
  /// static array of them will not compile under strict concurrency.
  static var fields: [(label: String, key: WritableKeyPath<BrewNotes, String>)] {
    [
      ("Beans", \.beans),
      ("Water Recipe", \.waterRecipe),
      ("Total Dissolved Solids", \.totalDissolvedSolids),
      ("Concentration", \.concentration),
      ("Aroma", \.aroma),
      ("Flavour", \.flavour),
      ("Aftertaste", \.aftertaste),
      ("Acidity", \.acidity),
      ("Sweetness", \.sweetness),
      ("Bitterness", \.bitterness),
      ("Texture", \.texture),
      ("Afterfeel", \.afterfeel),
      ("Balance", \.balance),
    ]
  }
}
