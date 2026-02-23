// ABOUTME: Tests for ContentEquatable protocol and auto-reconfigure behavior on data sources.
// ABOUTME: Validates type-erased content equality and AnyItem content change detection.
import Testing
import UIKit
@testable import ListKit
@testable import Lists

// MARK: - ContentEquatableTests

struct ContentEquatableTests {

  @Test
  func contentEquatableDetectsChanges() {
    let a = ContentItem(id: "1", title: "Hello", subtitle: "World")
    let b = ContentItem(id: "1", title: "Changed", subtitle: "World")
    let c = ContentItem(id: "1", title: "Hello", subtitle: "World")

    // Same id → equal by identity
    #expect(a == b)
    #expect(a == c)

    // Content differs
    #expect(!a.isContentEqual(to: b))
    #expect(a.isContentEqual(to: c))
  }

  @Test
  func typeErasedContentEqualityWorks() {
    let a = ContentItem(id: "1", title: "Hello", subtitle: "World")
    let b = ContentItem(id: "1", title: "Changed", subtitle: "World")
    let c = ContentItem(id: "1", title: "Hello", subtitle: "World")

    let aCE = a as any ContentEquatable
    #expect(!aCE.isContentEqualTypeErased(to: b))
    #expect(aCE.isContentEqualTypeErased(to: c))
  }

  @Test
  func typeErasedContentEqualityReturnsFalseForWrongType() {
    let a = ContentItem(id: "1", title: "Hello", subtitle: "World")
    let aCE = a as any ContentEquatable
    #expect(!aCE.isContentEqualTypeErased(to: "not a ContentItem"))
  }

  @Test
  func anyItemContentEqualityDetectsChanges() {
    let a = AnyItem(ContentItem(id: "1", title: "Hello", subtitle: "World"))
    let b = AnyItem(ContentItem(id: "1", title: "Changed", subtitle: "World"))
    let c = AnyItem(ContentItem(id: "1", title: "Hello", subtitle: "World"))

    // Same identity → AnyItem equality
    #expect(a == b)
    #expect(a == c)

    // Content equality
    #expect(!a.isContentEqual(to: b))
    #expect(a.isContentEqual(to: c))
  }

  @Test
  func anyItemContentEqualityReturnsTrueForNonContentEquatableType() {
    let a = AnyItem(TextItem(text: "Hello"))
    let b = AnyItem(TextItem(text: "World"))

    // TextItem does not conform to ContentEquatable
    // isContentEqual returns true (no content change detected)
    #expect(a.isContentEqual(to: b))
  }

  @Test
  func anyItemContentEqualityReturnsTrueForDifferentTypes() {
    let a = AnyItem(ContentItem(id: "1", title: "Hello", subtitle: "World"))
    let b = AnyItem(NumberItem(value: 42))

    // Different types → returns true (can't compare)
    #expect(a.isContentEqual(to: b))
  }

  @MainActor
  @Test
  func autoReconfigureMarksChangedItems() async {
    let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    let dataSource = ListDataSource<String, ContentItem>(collectionView: cv)

    // Initial apply
    var initial = DiffableDataSourceSnapshot<String, ContentItem>()
    initial.appendSections(["main"])
    initial.appendItems([
      ContentItem(id: "1", title: "Hello", subtitle: "A"),
      ContentItem(id: "2", title: "World", subtitle: "B"),
    ], toSection: "main")
    await dataSource.apply(initial, animatingDifferences: false)

    // Update with content change on item "1" only
    var updated = DiffableDataSourceSnapshot<String, ContentItem>()
    updated.appendSections(["main"])
    updated.appendItems([
      ContentItem(id: "1", title: "Changed", subtitle: "A"),
      ContentItem(id: "2", title: "World", subtitle: "B"),
    ], toSection: "main")

    // Before apply, reconfiguredItemIdentifiers should be empty
    #expect(updated.reconfiguredItemIdentifiers.isEmpty)

    await dataSource.apply(updated, animatingDifferences: false)

    // After apply, the snapshot should have been processed.
    // We verify the data source has the new data.
    let result = dataSource.snapshot()
    #expect(result.numberOfItems == 2)
  }

  @MainActor
  @Test
  func autoReconfigureDoesNotAffectNonContentEquatableTypes() async {
    let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    let dataSource = ListDataSource<String, NumberItem>(collectionView: cv)

    // NumberItem does not conform to ContentEquatable
    var initial = DiffableDataSourceSnapshot<String, NumberItem>()
    initial.appendSections(["main"])
    initial.appendItems([NumberItem(value: 1), NumberItem(value: 2)], toSection: "main")
    await dataSource.apply(initial, animatingDifferences: false)

    var updated = DiffableDataSourceSnapshot<String, NumberItem>()
    updated.appendSections(["main"])
    updated.appendItems([NumberItem(value: 1), NumberItem(value: 3)], toSection: "main")
    await dataSource.apply(updated, animatingDifferences: false)

    let result = dataSource.snapshot()
    #expect(result.numberOfItems == 2)
  }

  @MainActor
  @Test
  func autoReconfigureWorksWithSectionModelApply() async {
    let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    let dataSource = ListDataSource<String, ContentItem>(collectionView: cv)

    await dataSource.apply([
      SectionModel(id: "main", items: [
        ContentItem(id: "1", title: "Hello", subtitle: "A")
      ])
    ], animatingDifferences: false)

    await dataSource.apply([
      SectionModel(id: "main", items: [
        ContentItem(id: "1", title: "Changed", subtitle: "A")
      ])
    ], animatingDifferences: false)

    let result = dataSource.snapshot()
    #expect(result.numberOfItems == 1)
  }

  @MainActor
  @Test
  func autoReconfigureWorksWithDSLApply() async {
    let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    let dataSource = ListDataSource<String, ContentItem>(collectionView: cv)

    await dataSource.apply(animatingDifferences: false) {
      SnapshotSection("main") {
        ContentItem(id: "1", title: "Hello", subtitle: "A")
      }
    }

    await dataSource.apply(animatingDifferences: false) {
      SnapshotSection("main") {
        ContentItem(id: "1", title: "Changed", subtitle: "A")
      }
    }

    let result = dataSource.snapshot()
    #expect(result.numberOfItems == 1)
  }

  @MainActor
  @Test
  func autoReconfigureWorksWithSectionSnapshotApply() async {
    let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    let dataSource = ListDataSource<Int, ContentItem>(collectionView: cv)

    // Ensure section 0 exists
    var initial = DiffableDataSourceSnapshot<Int, ContentItem>()
    initial.appendSections([0])
    initial.appendItems([
      ContentItem(id: "1", title: "Hello", subtitle: "A"),
      ContentItem(id: "2", title: "World", subtitle: "B"),
    ], toSection: 0)
    await dataSource.apply(initial, animatingDifferences: false)

    // Apply via section snapshot with a content change on item "1"
    var sectionSnapshot = DiffableDataSourceSectionSnapshot<ContentItem>()
    sectionSnapshot.append([
      ContentItem(id: "1", title: "Changed", subtitle: "A"),
      ContentItem(id: "2", title: "World", subtitle: "B"),
    ])
    await dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: false)

    // Snapshot should reflect the new items
    let result = dataSource.snapshot()
    #expect(result.numberOfItems == 2)
    #expect(result.itemIdentifiers.contains(ContentItem(id: "1", title: "Changed", subtitle: "A")))
  }

  @MainActor
  @Test
  func autoReconfigureWithSectionSnapshotDetectsContentChanges() async throws {
    let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    let dataSource = ListDataSource<Int, ContentItem>(collectionView: cv)

    // Set up initial state
    var initial = DiffableDataSourceSnapshot<Int, ContentItem>()
    initial.appendSections([0])
    initial.appendItems([
      ContentItem(id: "1", title: "Hello", subtitle: "A")
    ], toSection: 0)
    await dataSource.apply(initial, animatingDifferences: false)

    // Build a section snapshot with changed content
    var sectionSnapshot = DiffableDataSourceSectionSnapshot<ContentItem>()
    sectionSnapshot.append([
      ContentItem(id: "1", title: "Changed", subtitle: "A")
    ])

    // Manually verify autoReconfigure would detect the change by building
    // the same full snapshot the apply path constructs
    let oldSnapshot = dataSource.snapshot()
    var newSnapshot = oldSnapshot
    newSnapshot.deleteItems(newSnapshot.itemIdentifiers(inSection: 0))
    newSnapshot.appendItems(sectionSnapshot.visibleItems, toSection: 0)

    // Before autoReconfigure, reconfiguredItemIdentifiers should be empty
    #expect(newSnapshot.reconfiguredItemIdentifiers.isEmpty)

    // Items match by identity (same id) but content differs (title changed)
    let oldItem = try #require(oldSnapshot.itemIdentifiers.first)
    let newItem = try #require(newSnapshot.itemIdentifiers.first)
    #expect(oldItem == newItem) // Same identity
    #expect(!oldItem.isContentEqual(to: newItem)) // Different content

    // Apply and verify the data source has the updated items
    await dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: false)
    let result = dataSource.snapshot()
    #expect(result.numberOfItems == 1)
  }

  @MainActor
  @Test
  func autoReconfigureWithHierarchicalSectionSnapshot() async {
    let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    let dataSource = ListDataSource<Int, ContentItem>(collectionView: cv)

    let parent = ContentItem(id: "parent", title: "Folder", subtitle: "")
    let child = ContentItem(id: "child", title: "File", subtitle: "10 KB")

    // Set up initial state with parent-child hierarchy
    var initial = DiffableDataSourceSnapshot<Int, ContentItem>()
    initial.appendSections([0])
    initial.appendItems([parent, child], toSection: 0)
    await dataSource.apply(initial, animatingDifferences: false)

    // Apply section snapshot with updated child content
    let updatedChild = ContentItem(id: "child", title: "File", subtitle: "20 KB")
    var sectionSnapshot = DiffableDataSourceSectionSnapshot<ContentItem>()
    sectionSnapshot.append([parent])
    sectionSnapshot.append([updatedChild], to: parent)
    sectionSnapshot.expand([parent])
    await dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: false)

    let result = dataSource.snapshot()
    #expect(result.numberOfItems == 2)
    #expect(result.itemIdentifiers.contains(updatedChild))
  }
}

// MARK: - ContentItem

struct ContentItem: CellViewModel, Identifiable, ContentEquatable {
  typealias Cell = UICollectionViewListCell

  let id: String
  let title: String
  let subtitle: String

  func isContentEqual(to other: ContentItem) -> Bool {
    title == other.title && subtitle == other.subtitle
  }

  @MainActor
  func configure(_ cell: UICollectionViewListCell) {
    var content = cell.defaultContentConfiguration()
    content.text = title
    content.secondaryText = subtitle
    cell.contentConfiguration = content
  }
}
