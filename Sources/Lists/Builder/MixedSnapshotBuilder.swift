/// A section containing mixed `CellViewModel` types, wrapped as ``AnyItem``.
///
/// Use with ``MixedSnapshotBuilder`` to build heterogeneous sections where each
/// item can be a different `CellViewModel` type.
public struct MixedSection<SectionID: Hashable & Sendable>: Sendable {
    /// The section identifier.
    public let id: SectionID
    /// The type-erased items in this section.
    public let items: [AnyItem]

    /// Creates a section using the ``MixedItemsBuilder`` result builder.
    public init(_ id: SectionID, @MixedItemsBuilder items: () -> [AnyItem]) {
        self.id = id
        self.items = items()
    }

    /// Creates a section from an existing array of type-erased items.
    public init(_ id: SectionID, items: [AnyItem]) {
        self.id = id
        self.items = items
    }
}

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
}

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
}
