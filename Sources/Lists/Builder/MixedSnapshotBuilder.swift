// MARK: - MixedSection

/// A section containing mixed `CellViewModel` types, wrapped as ``AnyItem``.
///
/// Use with ``MixedSnapshotBuilder`` to build heterogeneous sections where each
/// item can be a different `CellViewModel` type.
public struct MixedSection<SectionID: Hashable & Sendable>: Sendable {

  // MARK: Lifecycle

  /// Creates a section using the ``MixedItemsBuilder`` result builder.
  public init(
    _ id: SectionID,
    header: String? = nil,
    footer: String? = nil,
    @MixedItemsBuilder items: () -> [AnyItem]
  ) {
    self.id = id
    self.header = header
    self.footer = footer
    self.items = items()
  }

  /// Creates a section from an existing array of type-erased items.
  public init(_ id: SectionID, items: [AnyItem], header: String? = nil, footer: String? = nil) {
    self.id = id
    self.header = header
    self.footer = footer
    self.items = items
  }

  // MARK: Public

  /// The section identifier.
  public let id: SectionID
  /// The type-erased items in this section.
  public let items: [AnyItem]
  /// Optional header text for the section.
  ///
  /// > Note: `MixedListDataSource.apply(content:)` does not automatically render headers.
  /// > Use this property when manually configuring supplementary views on the data source.
  public let header: String?
  /// Optional footer text for the section.
  ///
  /// > Note: `MixedListDataSource.apply(content:)` does not automatically render footers.
  /// > Use this property when manually configuring supplementary views on the data source.
  public let footer: String?

}

// MARK: - MixedItemsBuilder

/// Result builder for items within a `MixedSection`. Accepts any `CellViewModel` type.
@resultBuilder
public struct MixedItemsBuilder {
  public static func buildBlock(_ components: [AnyItem]...) -> [AnyItem] {
    components.flatMap(\.self)
  }

  public static func buildExpression(_ item: some CellViewModel) -> [AnyItem] {
    [AnyItem(item)]
  }

  public static func buildExpression(_ items: [some CellViewModel]) -> [AnyItem] {
    items.map(AnyItem.init)
  }

  public static func buildExpression(_ items: [AnyItem]) -> [AnyItem] {
    items
  }

  public static func buildOptional(_ component: [AnyItem]?) -> [AnyItem] {
    component ?? []
  }

  public static func buildEither(first component: [AnyItem]) -> [AnyItem] {
    component
  }

  public static func buildEither(second component: [AnyItem]) -> [AnyItem] {
    component
  }

  public static func buildArray(_ components: [[AnyItem]]) -> [AnyItem] {
    components.flatMap(\.self)
  }

  public static func buildLimitedAvailability(_ component: [AnyItem]) -> [AnyItem] {
    component
  }
}

// MARK: - MixedSnapshotBuilder

/// Result builder for constructing arrays of `MixedSection`.
@resultBuilder
public struct MixedSnapshotBuilder<SectionID: Hashable & Sendable> {
  public static func buildBlock(_ components: [MixedSection<SectionID>]...) -> [MixedSection<SectionID>] {
    components.flatMap(\.self)
  }

  public static func buildExpression(_ section: MixedSection<SectionID>) -> [MixedSection<SectionID>] {
    [section]
  }

  public static func buildOptional(_ component: [MixedSection<SectionID>]?) -> [MixedSection<SectionID>] {
    component ?? []
  }

  public static func buildEither(first component: [MixedSection<SectionID>]) -> [MixedSection<SectionID>] {
    component
  }

  public static func buildEither(second component: [MixedSection<SectionID>]) -> [MixedSection<SectionID>] {
    component
  }

  public static func buildArray(_ components: [[MixedSection<SectionID>]]) -> [MixedSection<SectionID>] {
    components.flatMap(\.self)
  }

  public static func buildLimitedAvailability(_ component: [MixedSection<SectionID>]) -> [MixedSection<SectionID>] {
    component
  }
}
