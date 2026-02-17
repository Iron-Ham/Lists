// ABOUTME: Section struct bundling an ID, items array, and optional header/footer text.
// ABOUTME: Used by GroupedList and ListDataSource for multi-section list definitions.
// MARK: - SectionModel

/// A section with an identifier, items, and optional header/footer text.
///
/// Use `SectionModel` with ``GroupedList`` or ``ListDataSource`` to define
/// multi-section lists with headers and footers.
///
/// The `Item` constraint is `Hashable & Sendable` rather than ``CellViewModel`` so that
/// `SectionModel` can also be used with the inline-content convenience initializers on
/// ``GroupedListView``, where items are plain data values wrapped in ``InlineCellViewModel``.
/// APIs that need ``CellViewModel`` (e.g. ``ListDataSource``) add that constraint themselves.
public struct SectionModel<SectionID: Hashable & Sendable, Item: Hashable & Sendable>: Sendable, Equatable,
  Identifiable
{

  // MARK: Lifecycle

  /// Creates a section with the given identifier, items, and optional header/footer.
  public init(id: SectionID, items: [Item], header: String? = nil, footer: String? = nil) {
    self.id = id
    self.items = items
    self.header = header
    self.footer = footer
  }

  // MARK: Public

  /// The unique identifier for this section.
  public let id: SectionID
  /// The items displayed in this section.
  public let items: [Item]
  /// Optional header text displayed above the section.
  public let header: String?
  /// Optional footer text displayed below the section.
  public let footer: String?

  /// Transforms every item in this section using the given closure, preserving the
  /// section identifier, header, and footer.
  public func mapItems<T: Hashable & Sendable>(_ transform: (Item) -> T) -> SectionModel<SectionID, T> {
    SectionModel<SectionID, T>(
      id: id,
      items: items.map(transform),
      header: header,
      footer: footer
    )
  }

}

extension SectionModel where Item: CellViewModel {
  /// Creates a section using the ``ItemsBuilder`` result builder DSL.
  ///
  /// ```swift
  /// let section = SectionModel(id: "friends", header: "Friends") {
  ///     contactA
  ///     contactB
  ///     contactC
  /// }
  /// ```
  public init(
    id: SectionID,
    header: String? = nil,
    footer: String? = nil,
    @ItemsBuilder<Item> items: () -> [Item]
  ) {
    self.init(id: id, items: items(), header: header, footer: footer)
  }
}
