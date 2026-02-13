public struct SnapshotSection<SectionID: Hashable & Sendable, Item: CellViewModel>: Sendable {
    public let id: SectionID
    public let items: [Item]

    public init(_ id: SectionID, @ItemsBuilder<Item> items: () -> [Item]) {
        self.id = id
        self.items = items()
    }

    public init(_ id: SectionID, items: [Item]) {
        self.id = id
        self.items = items
    }
}

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
