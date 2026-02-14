import Testing
import UIKit
@testable import ListKit

/// Tests for data source lifecycle, serialization, and edge cases.
/// Inspired by IGListKit's IGListAdapterE2ETests.
@MainActor
struct DataSourceLifecycleTests {

  // MARK: Internal

  /// Multiple rapid apply() calls via completion handler should serialize and all complete.
  @Test
  func rapidApplyCallsSerialize() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Fire 10 rapid applies without awaiting each one (completion handler variant)
    // This is the real-world pattern: `Task { await apply(...) }` called repeatedly
    for i in 0 ..< 10 {
      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["A"])
      snapshot.appendItems(Array(0 ..< (i + 1) * 10), toSection: "A")
      ds.apply(snapshot, animatingDifferences: false, completion: nil)
    }

    // Apply one final snapshot and await it — forces all queued applies to drain
    var finalSnapshot = DiffableDataSourceSnapshot<String, Int>()
    finalSnapshot.appendSections(["A"])
    finalSnapshot.appendItems(Array(0 ..< 100), toSection: "A")
    await ds.apply(finalSnapshot, animatingDifferences: false)

    // After all applies complete, the snapshot should reflect the last apply
    let final = ds.snapshot()
    #expect(final.sectionIdentifiers == ["A"])
    #expect(final.numberOfItems == 100)
  }

  /// Sequential applies should produce consistent final state.
  @Test
  func sequentialAppliesProduceConsistentState() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snap1 = DiffableDataSourceSnapshot<String, Int>()
    snap1.appendSections(["A"])
    snap1.appendItems([1, 2, 3], toSection: "A")
    await ds.apply(snap1, animatingDifferences: false)

    var snap2 = DiffableDataSourceSnapshot<String, Int>()
    snap2.appendSections(["A", "B"])
    snap2.appendItems([1, 2], toSection: "A")
    snap2.appendItems([4, 5], toSection: "B")
    await ds.apply(snap2, animatingDifferences: false)

    var snap3 = DiffableDataSourceSnapshot<String, Int>()
    snap3.appendSections(["B"])
    snap3.appendItems([4, 5, 6], toSection: "B")
    await ds.apply(snap3, animatingDifferences: false)

    let final = ds.snapshot()
    #expect(final.sectionIdentifiers == ["B"])
    #expect(final.itemIdentifiers == [4, 5, 6])
  }

  /// Data source should not crash when collection view is deallocated.
  @Test
  func applyAfterCollectionViewDeallocated() async {
    let ds: CollectionViewDiffableDataSource<String, Int>

    // Scope the collection view so it deallocates
    do {
      let cv = makeCollectionView()
      ds = makeDataSource(collectionView: cv)

      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["A"])
      snapshot.appendItems([1, 2], toSection: "A")
      await ds.applySnapshotUsingReloadData(snapshot)
    }

    // Collection view is nil now — apply should not crash (it early-returns)
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    await ds.apply(snapshot, animatingDifferences: false)

    // Snapshot retains last successfully applied state (apply no-ops when CV is nil)
    let current = ds.snapshot()
    #expect(current.itemIdentifiers == [1, 2])
  }

  /// Applying an empty snapshot should clear everything.
  @Test
  func applyEmptySnapshotClearsState() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.numberOfSections(in: cv) == 1)

    // Apply empty snapshot
    let empty = DiffableDataSourceSnapshot<String, Int>()
    await ds.apply(empty, animatingDifferences: false)

    #expect(ds.numberOfSections(in: cv) == 0)
    #expect(ds.snapshot().numberOfItems == 0)
  }

  /// Applying populated snapshot after empty should work.
  @Test
  func applyPopulatedAfterEmpty() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Start empty, apply populated
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    await ds.apply(snapshot, animatingDifferences: false)

    #expect(ds.numberOfSections(in: cv) == 1)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 3)
  }

  /// applySnapshotUsingReloadData should bypass diffing entirely.
  @Test
  func reloadDataBypassesDiffing() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Apply initial
    var snap1 = DiffableDataSourceSnapshot<String, Int>()
    snap1.appendSections(["A"])
    snap1.appendItems([1, 2, 3], toSection: "A")
    await ds.applySnapshotUsingReloadData(snap1)

    // Completely different snapshot via reloadData
    var snap2 = DiffableDataSourceSnapshot<String, Int>()
    snap2.appendSections(["X", "Y"])
    snap2.appendItems([10, 20], toSection: "X")
    snap2.appendItems([30], toSection: "Y")
    await ds.applySnapshotUsingReloadData(snap2)

    #expect(ds.numberOfSections(in: cv) == 2)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 2)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 1) == 1)
  }

  /// After apply, the snapshot() should reflect the new state.
  @Test
  func snapshotReflectsLatestApply() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snap1 = DiffableDataSourceSnapshot<String, Int>()
    snap1.appendSections(["A"])
    snap1.appendItems([1, 2], toSection: "A")
    await ds.apply(snap1, animatingDifferences: false)

    var snap2 = DiffableDataSourceSnapshot<String, Int>()
    snap2.appendSections(["A", "B"])
    snap2.appendItems([1], toSection: "A")
    snap2.appendItems([3, 4], toSection: "B")
    await ds.apply(snap2, animatingDifferences: false)

    let current = ds.snapshot()
    #expect(current.sectionIdentifiers == ["A", "B"])
    #expect(current.itemIdentifiers(inSection: "A") == [1])
    #expect(current.itemIdentifiers(inSection: "B") == [3, 4])
  }

  /// When no supplementary view provider is set, fallback registration should
  /// prevent a crash when UICollectionView requests a supplementary view.
  @Test
  func supplementaryViewFallbackDoesNotCrash() {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // No supplementary provider set — should use fallback
    #expect(ds.supplementaryViewProvider == nil)

    // The fallback registration should work without crashing
    // (Can't fully test dequeue without a layout that requests supplementaries,
    // but we can verify the provider is nil and the data source handles it)
  }

  /// When a supplementary view provider is set, it should be used.
  @Test
  func supplementaryViewProviderIsUsed() {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var providerCalled = false
    ds.supplementaryViewProvider = { _, _, _ in
      providerCalled = true
      return UICollectionReusableView()
    }

    // Trigger the provider — returns a valid view so no fallback dequeue needed
    _ = ds.collectionView(cv, viewForSupplementaryElementOfKind: "header", at: IndexPath(item: 0, section: 0))
    #expect(providerCalled)
  }

  /// Querying with out-of-bounds section should return nil.
  @Test
  func outOfBoundsSectionReturnsNil() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.itemIdentifier(for: IndexPath(item: 0, section: 5)) == nil)
    #expect(ds.sectionIdentifier(for: 99) == nil)
  }

  /// Querying with out-of-bounds item should return nil.
  @Test
  func outOfBoundsItemReturnsNil() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.itemIdentifier(for: IndexPath(item: 99, section: 0)) == nil)
  }

  /// Querying for non-existent item should return nil.
  @Test
  func nonExistentItemReturnsNilIndexPath() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2], toSection: "A")
    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.indexPath(for: 999) == nil)
  }

  /// Querying for non-existent section should return nil.
  @Test
  func nonExistentSectionReturnsNilIndex() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    await ds.applySnapshotUsingReloadData(snapshot)

    #expect(ds.index(for: "Z") == nil)
  }

  /// Completion handler variant should execute the callback.
  @Test
  func completionHandlerApplyCallsCompletion() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      ds.apply(snapshot, animatingDifferences: false) {
        continuation.resume()
      }
    }

    #expect(ds.snapshot().itemIdentifiers == [1, 2, 3])
  }

  /// Multiple completion handler applies should all complete in order.
  @Test
  func multipleCompletionHandlerAppliesCompleteInOrder() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var order = [Int]()

    var snap1 = DiffableDataSourceSnapshot<String, Int>()
    snap1.appendSections(["A"])
    snap1.appendItems([1], toSection: "A")

    var snap2 = DiffableDataSourceSnapshot<String, Int>()
    snap2.appendSections(["A"])
    snap2.appendItems([1, 2], toSection: "A")

    var snap3 = DiffableDataSourceSnapshot<String, Int>()
    snap3.appendSections(["A"])
    snap3.appendItems([1, 2, 3], toSection: "A")

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      ds.apply(snap1, animatingDifferences: false) {
        order.append(1)
      }
      ds.apply(snap2, animatingDifferences: false) {
        order.append(2)
      }
      ds.apply(snap3, animatingDifferences: false) {
        order.append(3)
        continuation.resume()
      }
    }

    #expect(order == [1, 2, 3])
    #expect(ds.snapshot().itemIdentifiers == [1, 2, 3])
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
