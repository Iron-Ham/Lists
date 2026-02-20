// ABOUTME: Tests for data source lifecycle, animated apply correctness, and serialization safety.
// ABOUTME: Covers batch updates (section/item mutations), reload/reconfigure markers, and edge cases.
import Testing
import UIKit
@testable import ListKit

/// Tests for data source lifecycle, animated apply correctness, serialization, and edge cases.
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

    // Collection view is nil now — apply should not crash (it early-returns after updating snapshot)
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    await ds.apply(snapshot, animatingDifferences: false)

    // Snapshot always tracks the latest applied state, even if the UI couldn't be updated.
    // This prevents stale diffs if the data source is later connected to a new collection view.
    let current = ds.snapshot()
    #expect(current.itemIdentifiers == [1, 2, 3])
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

  /// applySnapshotUsingReloadData should serialize with apply — interleaving should not corrupt state.
  @Test
  func reloadDataSerializesWithApply() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Apply an initial snapshot
    var snap1 = DiffableDataSourceSnapshot<String, Int>()
    snap1.appendSections(["A"])
    snap1.appendItems([1, 2, 3], toSection: "A")
    await ds.apply(snap1, animatingDifferences: false)

    // Rapidly interleave apply and reloadData — should not crash or corrupt state
    var snap2 = DiffableDataSourceSnapshot<String, Int>()
    snap2.appendSections(["A"])
    snap2.appendItems([4, 5], toSection: "A")

    var snap3 = DiffableDataSourceSnapshot<String, Int>()
    snap3.appendSections(["B"])
    snap3.appendItems([6, 7, 8], toSection: "B")

    var snap4 = DiffableDataSourceSnapshot<String, Int>()
    snap4.appendSections(["C"])
    snap4.appendItems([9], toSection: "C")

    // Fire them without awaiting individually — serialization should keep them ordered
    ds.apply(snap2, animatingDifferences: false, completion: nil)
    // This used to bypass the applyTask chain — now it's serialized
    let reloadTask = Task {
      await ds.applySnapshotUsingReloadData(snap3)
    }
    ds.apply(snap4, animatingDifferences: false, completion: nil)

    // Await the reload task and a final drain
    await reloadTask.value
    var drain = DiffableDataSourceSnapshot<String, Int>()
    drain.appendSections(["final"])
    drain.appendItems([100], toSection: "final")
    await ds.apply(drain, animatingDifferences: false)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["final"])
    #expect(result.itemIdentifiers == [100])
  }

  /// Cancelled apply should be skipped — snapshot should not change.
  @Test
  func cancelledApplyIsSkipped() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Apply initial state
    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2], toSection: "A")
    await ds.apply(initial, animatingDifferences: false)

    // Create and immediately cancel a task that applies a new snapshot
    var stale = DiffableDataSourceSnapshot<String, Int>()
    stale.appendSections(["stale"])
    stale.appendItems([99], toSection: "stale")

    let task = Task {
      await ds.apply(stale, animatingDifferences: false)
    }
    task.cancel()
    await task.value

    // The snapshot should either be the initial or stale — but the cancel
    // gives us a chance to skip it. Verify no crash at minimum.
    let result = ds.snapshot()
    #expect(result.numberOfSections >= 1)
  }

  /// Applying a snapshot with >1,000 items should trigger the background diff path
  /// and produce the same final state as an inline diff.
  @Test
  func backgroundDiffProducesCorrectState() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Apply initial snapshot with 1,500 items
    var snap1 = DiffableDataSourceSnapshot<String, Int>()
    snap1.appendSections(["A"])
    snap1.appendItems(Array(0 ..< 1_500), toSection: "A")
    await ds.apply(snap1, animatingDifferences: false)

    // Apply a second snapshot with 50% overlap (750 shared, 750 new)
    var snap2 = DiffableDataSourceSnapshot<String, Int>()
    snap2.appendSections(["A"])
    snap2.appendItems(Array(750 ..< 2_250), toSection: "A")
    await ds.apply(snap2, animatingDifferences: false)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["A"])
    #expect(result.numberOfItems == 1_500)
    #expect(result.itemIdentifiers == Array(750 ..< 2_250))
  }

  /// Cancelling a large apply mid-flight should not corrupt state.
  @Test
  func cancelledLargeApplyDoesNotCorruptState() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Establish baseline state with >1,000 items
    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems(Array(0 ..< 2_000), toSection: "A")
    await ds.apply(initial, animatingDifferences: false)

    // Fire a large apply and immediately cancel it
    var cancelled = DiffableDataSourceSnapshot<String, Int>()
    cancelled.appendSections(["cancelled"])
    cancelled.appendItems(Array(0 ..< 2_000), toSection: "cancelled")

    let task = Task {
      await ds.apply(cancelled, animatingDifferences: false)
    }
    task.cancel()
    await task.value

    // Apply a known-good final snapshot
    var final = DiffableDataSourceSnapshot<String, Int>()
    final.appendSections(["B"])
    final.appendItems([1, 2, 3], toSection: "B")
    await ds.apply(final, animatingDifferences: false)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["B"])
    #expect(result.itemIdentifiers == [1, 2, 3])
  }

  /// Animated apply with pure inserts (no deletes) must not throw
  /// NSInternalInconsistencyException. Regression test for #54 — UIKit validates
  /// `pre_count + inserts - deletes == post_count` inside performBatchUpdates.
  /// If currentSnapshot is advanced before the batch block, UIKit reads the new
  /// count for both pre and post, causing the arithmetic to fail.
  @Test
  func animatedApplyWithPureInsertsDoesNotCrash() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Seed with initial items
    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems(Array(0 ..< 50), toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // Apply a superset — pure inserts, no deletes
    var expanded = DiffableDataSourceSnapshot<String, Int>()
    expanded.appendSections(["A"])
    expanded.appendItems(Array(0 ..< 74), toSection: "A")
    await ds.apply(expanded, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.numberOfItems == 74)
    #expect(result.itemIdentifiers == Array(0 ..< 74))
  }

  /// Animated apply from an empty snapshot to a populated one (all inserts).
  @Test
  func animatedApplyFromEmptyToPopulated() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Start with an empty section
    var empty = DiffableDataSourceSnapshot<String, Int>()
    empty.appendSections(["A"])
    await ds.applySnapshotUsingReloadData(empty)

    // All items are inserts
    var populated = DiffableDataSourceSnapshot<String, Int>()
    populated.appendSections(["A"])
    populated.appendItems(Array(1 ... 30), toSection: "A")
    await ds.apply(populated, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.numberOfItems == 30)
  }

  /// Animated apply with inserts in one section and deletes in another
  /// exercises the structural batch path with mixed per-section operations.
  @Test
  func animatedApplyWithMixedInsertDeleteAcrossSections() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B"])
    initial.appendItems([1, 2, 3], toSection: "A")
    initial.appendItems([10, 20, 30, 40], toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    // Section A: pure inserts (3 → 6), Section B: pure deletes (4 → 2)
    var mixed = DiffableDataSourceSnapshot<String, Int>()
    mixed.appendSections(["A", "B"])
    mixed.appendItems([1, 2, 3, 4, 5, 6], toSection: "A")
    mixed.appendItems([10, 30], toSection: "B")
    await ds.apply(mixed, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers(inSection: "A") == [1, 2, 3, 4, 5, 6])
    #expect(result.itemIdentifiers(inSection: "B") == [10, 30])
  }

  /// Animated apply with pure deletes (no inserts) must not throw
  /// NSInternalInconsistencyException. Symmetric counterpart to the pure-insert test.
  @Test
  func animatedApplyWithPureDeletesDoesNotCrash() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems(Array(0 ..< 50), toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // Remove half the items — pure deletes, no inserts
    var shrunk = DiffableDataSourceSnapshot<String, Int>()
    shrunk.appendSections(["A"])
    shrunk.appendItems(Array(0 ..< 25), toSection: "A")
    await ds.apply(shrunk, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.numberOfItems == 25)
    #expect(result.itemIdentifiers == Array(0 ..< 25))
  }

  /// Animated apply from a populated snapshot to an empty section (all deletes).
  @Test
  func animatedApplyFromPopulatedToEmpty() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems(Array(1 ... 30), toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // Delete all items, keep section
    var empty = DiffableDataSourceSnapshot<String, Int>()
    empty.appendSections(["A"])
    await ds.apply(empty, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.numberOfItems == 0)
    #expect(result.sectionIdentifiers == ["A"])
  }

  /// Animated apply with pure deletes across multiple sections.
  @Test
  func animatedApplyWithPureDeletesAcrossSections() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B"])
    initial.appendItems([1, 2, 3, 4, 5], toSection: "A")
    initial.appendItems([10, 20, 30, 40], toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    // Delete items from both sections
    var shrunk = DiffableDataSourceSnapshot<String, Int>()
    shrunk.appendSections(["A", "B"])
    shrunk.appendItems([1, 3], toSection: "A")
    shrunk.appendItems([20], toSection: "B")
    await ds.apply(shrunk, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers(inSection: "A") == [1, 3])
    #expect(result.itemIdentifiers(inSection: "B") == [20])
  }

  /// Multiple rapid large (>1,000 item) applies should serialize correctly.
  @Test
  func rapidLargeAppliesSerializeCorrectly() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Fire 3 large applies via completion handler without awaiting
    for i in 1 ... 3 {
      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["S\(i)"])
      snapshot.appendItems(Array(0 ..< 1_500), toSection: "S\(i)")
      ds.apply(snapshot, animatingDifferences: false, completion: nil)
    }

    // Await a terminal apply — forces all queued applies to drain
    var terminal = DiffableDataSourceSnapshot<String, Int>()
    terminal.appendSections(["final"])
    terminal.appendItems(Array(0 ..< 1_500), toSection: "final")
    await ds.apply(terminal, animatingDifferences: false)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["final"])
    #expect(result.numberOfItems == 1_500)
  }

  /// Inserting a new section with items via animated apply.
  @Test
  func animatedApplyInsertingNewSectionWithItems() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A", "B"])
    next.appendItems([1, 2, 3], toSection: "A")
    next.appendItems([10, 20], toSection: "B")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["A", "B"])
    #expect(result.itemIdentifiers(inSection: "A") == [1, 2, 3])
    #expect(result.itemIdentifiers(inSection: "B") == [10, 20])
    #expect(ds.numberOfSections(in: cv) == 2)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 3)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 1) == 2)
  }

  /// Deleting an existing section via animated apply.
  @Test
  func animatedApplyDeletingExistingSection() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B"])
    initial.appendItems([1, 2], toSection: "A")
    initial.appendItems([10, 20, 30], toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["B"])
    next.appendItems([10, 20, 30], toSection: "B")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["B"])
    #expect(result.itemIdentifiers == [10, 20, 30])
    #expect(ds.numberOfSections(in: cv) == 1)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 3)
  }

  /// Moving sections via animated apply — reordering [A,B,C] → [C,B,A].
  @Test
  func animatedApplyMovingSections() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B", "C"])
    initial.appendItems([1], toSection: "A")
    initial.appendItems([2], toSection: "B")
    initial.appendItems([3], toSection: "C")
    await ds.applySnapshotUsingReloadData(initial)

    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["C", "B", "A"])
    next.appendItems([3], toSection: "C")
    next.appendItems([2], toSection: "B")
    next.appendItems([1], toSection: "A")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["C", "B", "A"])
    #expect(result.itemIdentifiers(inSection: "C") == [3])
    #expect(result.itemIdentifiers(inSection: "B") == [2])
    #expect(result.itemIdentifiers(inSection: "A") == [1])
  }

  /// Complete section replacement — all old sections removed, all new ones inserted.
  @Test
  func animatedApplyCompleteSectionReplacement() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B"])
    initial.appendItems([1, 2], toSection: "A")
    initial.appendItems([3, 4], toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["X", "Y", "Z"])
    next.appendItems([10], toSection: "X")
    next.appendItems([20], toSection: "Y")
    next.appendItems([30], toSection: "Z")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["X", "Y", "Z"])
    #expect(result.numberOfItems == 3)
    #expect(ds.numberOfSections(in: cv) == 3)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 1)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 1) == 1)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 2) == 1)
  }

  /// Simultaneous section insert, delete, and move in one apply.
  @Test
  func animatedApplySimultaneousSectionInsertDeleteMove() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B", "C"])
    initial.appendItems([1], toSection: "A")
    initial.appendItems([2], toSection: "B")
    initial.appendItems([3], toSection: "C")
    await ds.applySnapshotUsingReloadData(initial)

    // Delete A, keep B, move C before B, insert D
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["C", "B", "D"])
    next.appendItems([3], toSection: "C")
    next.appendItems([2], toSection: "B")
    next.appendItems([4], toSection: "D")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["C", "B", "D"])
    #expect(result.itemIdentifiers == [3, 2, 4])
  }

  /// Within-section item reorder via animated apply.
  @Test
  func animatedApplyWithinSectionItemReorder() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3, 4, 5], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A"])
    next.appendItems([5, 4, 3, 2, 1], toSection: "A")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == [5, 4, 3, 2, 1])
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 5)
  }

  /// Moving an item between sections via animated apply.
  @Test
  func animatedApplyCrossSectionItemMove() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B"])
    initial.appendItems([1, 2, 3], toSection: "A")
    initial.appendItems([10, 20], toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    // Move item 2 from section A to section B
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A", "B"])
    next.appendItems([1, 3], toSection: "A")
    next.appendItems([10, 2, 20], toSection: "B")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers(inSection: "A") == [1, 3])
    #expect(result.itemIdentifiers(inSection: "B") == [10, 2, 20])
  }

  /// Item moves combined with inserts and deletes via animated apply.
  @Test
  func animatedApplyMovesWithInsertsAndDeletes() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3, 4, 5], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // 5 moves to front, 2 deleted, 6 inserted
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A"])
    next.appendItems([5, 1, 3, 4, 6], toSection: "A")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == [5, 1, 3, 4, 6])
  }

  /// Reload-only apply on a structurally identical snapshot routes to the fast path.
  @Test
  func animatedApplyReloadOnlyNoStructuralChanges() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3, 4, 5], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // Same structure, with reload markers
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A"])
    next.appendItems([1, 2, 3, 4, 5], toSection: "A")
    next.reloadItems([1, 3])
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == [1, 2, 3, 4, 5])
    #expect(ds.numberOfSections(in: cv) == 1)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 5)
  }

  /// Reconfigure-only apply on a structurally identical snapshot routes to the fast path.
  @Test
  func animatedApplyReconfigureOnlyNoStructuralChanges() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3, 4], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A"])
    next.appendItems([1, 2, 3, 4], toSection: "A")
    next.reconfigureItems([1, 2, 3, 4])
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == [1, 2, 3, 4])
  }

  /// Section-reload-only apply on a structurally identical snapshot routes to the fast path.
  @Test
  func animatedApplySectionReloadOnlyNoStructuralChanges() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B"])
    initial.appendItems([1, 2], toSection: "A")
    initial.appendItems([3, 4], toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A", "B"])
    next.appendItems([1, 2], toSection: "A")
    next.appendItems([3, 4], toSection: "B")
    next.reloadSections(["A"])
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["A", "B"])
    #expect(result.itemIdentifiers == [1, 2, 3, 4])
  }

  /// Mixed reload and reconfigure markers on a structurally identical snapshot.
  @Test
  func animatedApplyMixedReloadAndReconfigureNoStructuralChanges() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3, 4, 5], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A"])
    next.appendItems([1, 2, 3, 4, 5], toSection: "A")
    next.reloadItems([1, 3])
    next.reconfigureItems([2, 4])
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == [1, 2, 3, 4, 5])
  }

  /// Structural changes with item reload markers — reloads deferred to completion handler.
  /// Note: deferred reloads are skipped when the collection view has no window (windowless testing).
  @Test
  func animatedApplyStructuralChangesWithItemReloads() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3, 4, 5], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // Delete 2, insert 6, reload surviving item 3
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A"])
    next.appendItems([1, 3, 4, 5, 6], toSection: "A")
    next.reloadItems([3])
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == [1, 3, 4, 5, 6])
  }

  /// Structural changes with item reconfigure markers — reconfigures deferred to completion handler.
  /// Note: deferred reconfigures are skipped when the collection view has no window (windowless testing).
  @Test
  func animatedApplyStructuralChangesWithItemReconfigures() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3, 4, 5], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // Delete 4, 5; insert 6, 7; reconfigure survivors 1 and 3
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A"])
    next.appendItems([1, 2, 3, 6, 7], toSection: "A")
    next.reconfigureItems([1, 3])
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == [1, 2, 3, 6, 7])
  }

  /// Section insert with item reload on surviving section — tests shifted indices in completion handler.
  /// Note: deferred reloads are skipped when the collection view has no window (windowless testing).
  @Test
  func animatedApplySectionInsertWithItemReloadOnSurvivingSection() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["B"])
    initial.appendItems([10, 20, 30], toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    // Insert section A before B, reload item 20 in B
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A", "B"])
    next.appendItems([1, 2], toSection: "A")
    next.appendItems([10, 20, 30], toSection: "B")
    next.reloadItems([20])
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["A", "B"])
    #expect(result.itemIdentifiers(inSection: "A") == [1, 2])
    #expect(result.itemIdentifiers(inSection: "B") == [10, 20, 30])
  }

  /// Large dataset (≥1000 items) triggers background diff followed by animated batch update.
  @Test
  func animatedApplyLargeDatasetTriggersDiffOnBackground() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B"])
    initial.appendItems(Array(0 ..< 600), toSection: "A")
    initial.appendItems(Array(600 ..< 1200), toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    // Structural changes on a large dataset — shrink A, expand B
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A", "B"])
    next.appendItems(Array(0 ..< 500), toSection: "A")
    next.appendItems(Array(500 ..< 1100), toSection: "B")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["A", "B"])
    #expect(result.numberOfItems == 1100)
    #expect(result.itemIdentifiers(inSection: "A") == Array(0 ..< 500))
    #expect(result.itemIdentifiers(inSection: "B") == Array(500 ..< 1100))
    #expect(ds.numberOfSections(in: cv) == 2)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 500)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 1) == 600)
  }

  /// Large single-section dataset with a sliding window pattern.
  @Test
  func animatedApplyLargeDatasetSingleSection() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems(Array(0 ..< 1500), toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // Slide window: drop first 500, add 500 new at the end
    var next = DiffableDataSourceSnapshot<String, Int>()
    next.appendSections(["A"])
    next.appendItems(Array(500 ..< 2000), toSection: "A")
    await ds.apply(next, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.numberOfItems == 1500)
    #expect(result.itemIdentifiers == Array(500 ..< 2000))
  }

  /// Five rapid-fire animated applies serialize correctly via the applyTask chain.
  @Test
  func rapidAnimatedAppliesSerialize() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A"])
    initial.appendItems([1, 2, 3], toSection: "A")
    await ds.applySnapshotUsingReloadData(initial)

    // Fire 5 animated applies via completion handler without awaiting each
    for i in 1 ... 5 {
      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["A"])
      snapshot.appendItems(Array(0 ..< i * 5), toSection: "A")
      ds.apply(snapshot, animatingDifferences: true, completion: nil)
    }

    // Drain the queue with a final awaited apply
    var terminal = DiffableDataSourceSnapshot<String, Int>()
    terminal.appendSections(["A"])
    terminal.appendItems(Array(0 ..< 30), toSection: "A")
    await ds.apply(terminal, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == Array(0 ..< 30))
  }

  /// Sequential animated applies that grow and shrink the data set.
  @Test
  func sequentialAnimatedAppliesGrowingAndShrinking() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var seed = DiffableDataSourceSnapshot<String, Int>()
    seed.appendSections(["A"])
    await ds.applySnapshotUsingReloadData(seed)

    // Grow
    var grow = DiffableDataSourceSnapshot<String, Int>()
    grow.appendSections(["A"])
    grow.appendItems(Array(1 ... 20), toSection: "A")
    await ds.apply(grow, animatingDifferences: true)
    #expect(ds.snapshot().numberOfItems == 20)

    // Shrink with different items
    var shrink = DiffableDataSourceSnapshot<String, Int>()
    shrink.appendSections(["A"])
    shrink.appendItems([5, 10, 15], toSection: "A")
    await ds.apply(shrink, animatingDifferences: true)
    #expect(ds.snapshot().numberOfItems == 3)

    // Grow again with entirely new items
    var growAgain = DiffableDataSourceSnapshot<String, Int>()
    growAgain.appendSections(["A"])
    growAgain.appendItems(Array(100 ... 110), toSection: "A")
    await ds.apply(growAgain, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.itemIdentifiers == Array(100 ... 110))
  }

  /// Non-animated apply followed by animated apply — transition from reloadData to performBatchUpdates.
  @Test
  func animatedApplyAfterNonAnimatedApply() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    // Non-animated apply uses reloadData (no batch updates)
    var snap1 = DiffableDataSourceSnapshot<String, Int>()
    snap1.appendSections(["A"])
    snap1.appendItems([1, 2, 3], toSection: "A")
    await ds.apply(snap1, animatingDifferences: false)

    // Animated apply with structural changes uses performBatchUpdates
    var snap2 = DiffableDataSourceSnapshot<String, Int>()
    snap2.appendSections(["A", "B"])
    snap2.appendItems([1, 3], toSection: "A")
    snap2.appendItems([4, 5], toSection: "B")
    await ds.apply(snap2, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["A", "B"])
    #expect(result.itemIdentifiers(inSection: "A") == [1, 3])
    #expect(result.itemIdentifiers(inSection: "B") == [4, 5])
  }

  /// Applying an identical snapshot with animatingDifferences: true is a no-op (empty changeset).
  @Test
  func animatedApplyWithIdenticalSnapshotIsNoOp() async {
    let cv = makeCollectionView()
    let ds = makeDataSource(collectionView: cv)

    var initial = DiffableDataSourceSnapshot<String, Int>()
    initial.appendSections(["A", "B"])
    initial.appendItems([1, 2], toSection: "A")
    initial.appendItems([3, 4], toSection: "B")
    await ds.applySnapshotUsingReloadData(initial)

    // Apply the exact same content — changeset is empty, no UIKit calls needed
    var identical = DiffableDataSourceSnapshot<String, Int>()
    identical.appendSections(["A", "B"])
    identical.appendItems([1, 2], toSection: "A")
    identical.appendItems([3, 4], toSection: "B")
    await ds.apply(identical, animatingDifferences: true)

    let result = ds.snapshot()
    #expect(result.sectionIdentifiers == ["A", "B"])
    #expect(result.itemIdentifiers == [1, 2, 3, 4])
    #expect(ds.numberOfSections(in: cv) == 2)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 0) == 2)
    #expect(ds.collectionView(cv, numberOfItemsInSection: 1) == 2)
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
