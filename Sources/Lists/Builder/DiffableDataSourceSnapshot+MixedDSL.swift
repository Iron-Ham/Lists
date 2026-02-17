// ABOUTME: Mixed DSL extensions on DiffableDataSourceSnapshot for AnyItem snapshots.
// ABOUTME: Adds init(content:) using @MixedSnapshotBuilder for heterogeneous cells.
import ListKit

extension DiffableDataSourceSnapshot where ItemIdentifierType == AnyItem {
  /// Creates a snapshot from a ``MixedSnapshotBuilder`` result builder closure.
  public init(
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
