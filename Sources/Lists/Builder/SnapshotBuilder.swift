/// A section definition used by the ``SnapshotBuilder`` result builder DSL.
///
/// Each `SnapshotSection` pairs a section identifier with an array of items.
public struct SnapshotSection<SectionID: Hashable & Sendable, Item: CellViewModel>: Sendable {
    /// The section identifier.
    public let id: SectionID
    /// The items in this section.
    public let items: [Item]

    /// Creates a section using the ``ItemsBuilder`` result builder.
    public init(_ id: SectionID, @ItemsBuilder<Item> items: () -> [Item]) {
        self.id = id
        self.items = items()
    }

    /// Creates a section from an existing array of items.
    public init(_ id: SectionID, items: [Item]) {
        self.id = id
        self.items = items
    }
}

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
}
