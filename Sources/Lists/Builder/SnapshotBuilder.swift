// ABOUTME: @resultBuilder for single-type snapshots with SnapshotSection.
// ABOUTME: Defines SnapshotSection (section + items) and SnapshotBuilder.
// MARK: - SnapshotSection

/// A section definition used by the ``SnapshotBuilder`` result builder DSL.
///
/// Each `SnapshotSection` pairs a section identifier with an array of items
/// and optional header/footer text. Header and footer values are used by
/// ``GroupedList/setSections(animatingDifferences:content:)`` when building
/// from the DSL — other contexts (e.g. ``ListDataSource``) ignore them.
public struct SnapshotSection<SectionID: Hashable & Sendable, Item: CellViewModel>: Sendable {

  // MARK: Lifecycle

  /// Creates a section using the ``ItemsBuilder`` result builder.
  public init(
    _ id: SectionID,
    header: String? = nil,
    footer: String? = nil,
    @ItemsBuilder<Item> items: () -> [Item]
  ) {
    self.id = id
    self.items = items()
    self.header = header
    self.footer = footer
  }

  /// Creates a section from an existing array of items.
  public init(_ id: SectionID, items: [Item], header: String? = nil, footer: String? = nil) {
    self.id = id
    self.items = items
    self.header = header
    self.footer = footer
  }

  // MARK: Public

  /// The section identifier.
  public let id: SectionID
  /// The items in this section.
  public let items: [Item]
  /// Optional header text for this section. Used by ``GroupedList`` when applying via the DSL.
  public let header: String?
  /// Optional footer text for this section. Used by ``GroupedList`` when applying via the DSL.
  public let footer: String?

}

// MARK: - SnapshotBuilder

/// A result builder for constructing arrays of ``SnapshotSection`` declaratively.
///
/// Use with ``ListDataSource/apply(animatingDifferences:content:)`` to build
/// multi-section snapshots using Swift's result builder syntax.
@resultBuilder
public struct SnapshotBuilder<SectionID: Hashable & Sendable, Item: CellViewModel> {
  public static func buildBlock(_ components: [SnapshotSection<SectionID, Item>]...) -> [SnapshotSection<SectionID, Item>] {
    components.flatMap(\.self)
  }

  public static func buildExpression(_ section: SnapshotSection<SectionID, Item>) -> [SnapshotSection<SectionID, Item>] {
    [section]
  }

  public static func buildOptional(_ component: [SnapshotSection<SectionID, Item>]?) -> [SnapshotSection<SectionID, Item>] {
    component ?? []
  }

  public static func buildEither(first component: [SnapshotSection<SectionID, Item>]) -> [SnapshotSection<SectionID, Item>] {
    component
  }

  public static func buildEither(second component: [SnapshotSection<SectionID, Item>]) -> [SnapshotSection<SectionID, Item>] {
    component
  }

  public static func buildArray(_ components: [[SnapshotSection<SectionID, Item>]]) -> [SnapshotSection<SectionID, Item>] {
    components.flatMap(\.self)
  }

  public static func buildLimitedAvailability(_ component: [SnapshotSection<SectionID, Item>]) -> [SnapshotSection<
    SectionID,
    Item
  >] {
    component
  }
}
