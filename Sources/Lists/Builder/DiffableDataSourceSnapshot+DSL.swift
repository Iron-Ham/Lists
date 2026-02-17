// ABOUTME: DSL extensions on DiffableDataSourceSnapshot for single-type builders.
// ABOUTME: Adds init(content:) using @SnapshotBuilder for declarative snapshots.
import ListKit

extension DiffableDataSourceSnapshot where ItemIdentifierType: CellViewModel {
  /// Creates a snapshot from a ``SnapshotBuilder`` result builder closure.
  public init(
    @SnapshotBuilder<SectionIdentifierType, ItemIdentifierType> content: () -> [SnapshotSection<
      SectionIdentifierType,
      ItemIdentifierType
    >]
  ) {
    self.init()
    let sections = content()
    for section in sections {
      appendSections([section.id])
      appendItems(section.items, toSection: section.id)
    }
  }
}
