/// A section with an identifier, items, and optional header/footer text.
///
/// Use `SectionModel` with ``GroupedList`` or ``ListDataSource`` to define
/// multi-section lists with headers and footers.
public struct SectionModel<SectionID: Hashable & Sendable, Item: CellViewModel>: Sendable, Equatable {
  /// Creates a section with the given identifier, items, and optional header/footer.
  public init(id: SectionID, items: [Item], header: String? = nil, footer: String? = nil) {
    self.id = id
    self.items = items
    self.header = header
    self.footer = footer
  }

  /// The unique identifier for this section.
  public let id: SectionID
  /// The items displayed in this section.
  public let items: [Item]
  /// Optional header text displayed above the section.
  public let header: String?
  /// Optional footer text displayed below the section.
  public let footer: String?

}
