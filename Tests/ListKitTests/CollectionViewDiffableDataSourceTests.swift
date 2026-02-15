import Testing
import UIKit
@testable import ListKit

@MainActor
struct CollectionViewDiffableDataSourceTests {

  // MARK: Internal

  @Test
  func initAssignsDataSource() {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)
    #expect(cv.dataSource === ds)
  }

  @Test
  func emptySnapshotReturnsZeroSections() {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)
    #expect(ds.numberOfSections(in: cv) == 0)
  }

  @Test
  func applySnapshotUpdatesSectionsAndItems() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    snapshot.appendItems([4, 5], toSection: "B")

    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.numberOfSections(in: cv) == 2)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 3)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 1) == 2)
  }

  @Test
  func itemIdentifierForIndexPath() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([10, 20, 30], toSection: "A")

    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.itemIdentifier(for: IndexPath(item: 0, section: 0)) == 10)
    #expect(ds.itemIdentifier(for: IndexPath(item: 1, section: 0)) == 20)
    #expect(ds.itemIdentifier(for: IndexPath(item: 2, section: 0)) == 30)
  }

  @Test
  func indexPathForItemIdentifier() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2], toSection: "A")
    snapshot.appendItems([3], toSection: "B")

    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.indexPath(for: 1) == IndexPath(item: 0, section: 0))
    #expect(ds.indexPath(for: 2) == IndexPath(item: 1, section: 0))
    #expect(ds.indexPath(for: 3) == IndexPath(item: 0, section: 1))
    #expect(ds.indexPath(for: 999) == nil)
  }

  @Test
  func sectionIdentifierAndIndex() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["X", "Y"])
    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.sectionIdentifier(for: 0) == "X")
    #expect(ds.sectionIdentifier(for: 1) == "Y")
    #expect(ds.sectionIdentifier(for: 5) == nil)
    #expect(ds.index(for: "X") == 0)
    #expect(ds.index(for: "Y") == 1)
  }

  @Test
  func snapshotReturnsCurrentState() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    let current = ds.snapshot()
    #expect(current.sectionIdentifiers == ["A"])
    #expect(current.itemIdentifiers == [1, 2])
  }

  @Test
  func moveItemAtUpdatesSnapshot() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    // Move item at position 0 to position 2
    ds.collectionView(cv, moveItemAt: IndexPath(item: 0, section: 0), to: IndexPath(item: 2, section: 0))

    let current = ds.snapshot()
    #expect(current.itemIdentifiers == [2, 3, 1])
  }

  @Test
  func moveItemAtAcrossSectionsUpdatesSnapshot() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2], toSection: "A")
    snapshot.appendItems([3, 4], toSection: "B")
    await ds.applySnapshotUsingReloadData(snapshot)

    // Move item 1 from section A to the beginning of section B
    ds.collectionView(cv, moveItemAt: IndexPath(item: 0, section: 0), to: IndexPath(item: 0, section: 1))

    let current = ds.snapshot()
    #expect(current.itemIdentifiers(inSection: "A") == [2])
    #expect(current.itemIdentifiers(inSection: "B") == [1, 3, 4])
  }

  @Test
  func didMoveItemHandlerIsCalled() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    var calledSource: IndexPath?
    var calledDest: IndexPath?
    ds.didMoveItemHandler = { source, dest in
      calledSource = source
      calledDest = dest
    }

    let source = IndexPath(item: 0, section: 0)
    let dest = IndexPath(item: 2, section: 0)
    ds.collectionView(cv, moveItemAt: source, to: dest)

    #expect(calledSource == source)
    #expect(calledDest == dest)
  }

  @Test
  func canMoveItemAtDefaultsToFalse() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    // Default: no handler set → canMoveItemAt returns false
    #expect(ds.collectionView(cv, canMoveItemAt: IndexPath(item: 0, section: 0)) == false)

    // With handler returning true → canMoveItemAt returns true
    ds.canMoveItemHandler = { _ in true }
    #expect(ds.collectionView(cv, canMoveItemAt: IndexPath(item: 0, section: 0)) == true)
  }

  @Test
  func moveItemToEndOfSectionAppends() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    // Move item 1 to index 3 (past the end after delete) — should append
    ds.collectionView(cv, moveItemAt: IndexPath(item: 0, section: 0), to: IndexPath(item: 3, section: 0))

    let current = ds.snapshot()
    #expect(current.itemIdentifiers == [2, 3, 1])
  }

  @Test
  func moveItemToSamePositionIsNoOp() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    // Move item at index 1 to index 1 — should be effectively a no-op
    ds.collectionView(cv, moveItemAt: IndexPath(item: 1, section: 0), to: IndexPath(item: 1, section: 0))

    let current = ds.snapshot()
    #expect(current.itemIdentifiers == [1, 2, 3])
  }

  // MARK: Private

  private func makeCollectionView() -> UICollectionView {
    let layout = UICollectionViewFlowLayout()
    let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
    cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
    return cv
  }

  private func makeDataSource(
    collectionView: UICollectionView
  ) -> CollectionViewDiffableDataSource<String, Int> {
    CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, _ in
      cv.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
    }
  }

}
