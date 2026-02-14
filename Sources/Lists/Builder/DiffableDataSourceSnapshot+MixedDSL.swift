import ListKit

public extension DiffableDataSourceSnapshot where ItemIdentifierType == AnyItem {
    /// Creates a snapshot from a ``MixedSnapshotBuilder`` result builder closure.
    init(
        @MixedSnapshotBuilder<SectionIdentifierType> content: () -> [MixedSection<SectionIdentifierType>]
    ) {
        self.init()
        let sections = content()
        for section in sections {
            appendSections([section.id])
            appendItems(section.items, toSection: section.id)
        }
    }
}
