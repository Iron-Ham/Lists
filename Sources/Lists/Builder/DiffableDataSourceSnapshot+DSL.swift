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
