// ABOUTME: Benchmarks testing mixed operations (inserts + deletes + moves) in a single diff.
// ABOUTME: Three-way comparison: ListKit vs Apple (BenchItem.ID) vs IGListKit (diff algorithm).

import Foundation
import IGListDiffKit
import Testing
import UIKit

@testable import ListKit

// MARK: - MixedData

/// Holds old and new arrays for a mixed-operations benchmark scenario.
private struct MixedData<T> {
  let old: [T]
  let new: [T]
  let deleteCount: Int
  let insertCount: Int
  let moveCount: Int
  let stableCount: Int
}

/// Generates deterministic integer arrays with known insert/delete/move composition.
///
/// Layout:
///   old = [0, 1, 2, ..., count-1]
///   new = [stable items (in order)] + [inserted items] + [moved items (relocated)]
///
/// Deleted items are removed from the front, moved items are survivors relocated to the end,
/// and inserted items are brand new identifiers that don't exist in old.
private func makeMixedIntData(
  count: Int,
  deleteRatio: Double,
  insertRatio: Double,
  moveRatio: Double
) -> MixedData<Int> {
  let deleteCount = Int(Double(count) * deleteRatio)
  let insertCount = Int(Double(count) * insertRatio)
  let survivingCount = count - deleteCount
  let moveCount = Int(Double(survivingCount) * moveRatio)
  let stableCount = survivingCount - moveCount

  let old = Array(0 ..< count)

  // Stable: survivors that keep their relative order
  let stable = Array((deleteCount + moveCount) ..< count)
  // Inserted: brand new items not in old
  let inserted = Array(count ..< count + insertCount)
  // Moved: survivors relocated from their original position to the end
  let moved = Array(deleteCount ..< deleteCount + moveCount)

  return MixedData(
    old: old,
    new: stable + inserted + moved,
    deleteCount: deleteCount,
    insertCount: insertCount,
    moveCount: moveCount,
    stableCount: stableCount
  )
}

/// Generates deterministic UUID arrays with known insert/delete/move composition.
///
/// Same layout as `makeMixedIntData` but uses pre-generated UUIDs.
/// Matches the Apple-recommended `Identifiable` pattern where snapshots store `Item.ID`.
private func makeMixedUUIDData(
  count: Int,
  deleteRatio: Double,
  insertRatio: Double,
  moveRatio: Double
) -> MixedData<BenchItem.ID> {
  let deleteCount = Int(Double(count) * deleteRatio)
  let insertCount = Int(Double(count) * insertRatio)
  let survivingCount = count - deleteCount
  let moveCount = Int(Double(survivingCount) * moveRatio)
  let stableCount = survivingCount - moveCount

  let allIDs = makeBenchItemIDs(count + insertCount)
  let old = Array(allIDs[0 ..< count])

  let stable = Array(allIDs[(deleteCount + moveCount) ..< count])
  let inserted = Array(allIDs[count ..< count + insertCount])
  let moved = Array(allIDs[deleteCount ..< deleteCount + moveCount])

  return MixedData(
    old: old,
    new: stable + inserted + moved,
    deleteCount: deleteCount,
    insertCount: insertCount,
    moveCount: moveCount,
    stableCount: stableCount
  )
}

// MARK: - Collection View Factory

/// Creates an offscreen UICollectionView for benchmarking apply operations.
/// Matches the pattern from CollectionViewDiffableDataSourceTests.
@MainActor
private func makeCollectionView() -> UICollectionView {
  let layout = UICollectionViewFlowLayout()
  let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
  cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
  return cv
}

/// Measures the median duration of an async operation over `runs` iterations after `warmup` throwaway runs.
/// Each iteration calls `setup` (untimed) then `work` (timed).
@MainActor
private func benchmarkApply(
  warmup: Int = 5,
  runs: Int = 15,
  setup: @MainActor () async -> Void,
  work: @MainActor () async -> Void
) async -> Duration {
  let clock = ContinuousClock()
  for _ in 0 ..< warmup {
    await setup()
    await work()
  }
  var times = [Duration]()
  for _ in 0 ..< runs {
    await setup()
    let start = clock.now
    await work()
    times.append(clock.now - start)
  }
  times.sort()
  return times[times.count / 2]
}

// MARK: - MixedOperationsBenchmarks

/// Mixed-operations benchmarks: inserts + deletes + moves in a single diff.
///
/// Addresses the realistic scenario where multiple types of changes happen simultaneously
/// (e.g. a social feed refresh where posts are added, removed, and re-ranked at once).
///
/// Three-way comparison:
/// - **Diff algorithm**: ListKit's `SectionedDiff` vs IGListKit's `ListDiff`
/// - **Snapshot build**: ListKit vs Apple using `BenchItem.ID` (UUID)
/// - **Full pipeline**: ListKit build + diff end-to-end
/// - **Apply**: Full data source apply (diff + batch update) for Apple vs ListKit
struct MixedOperationsBenchmarks {

  @Test
  func moderateChurn10k() {
    let intData = makeMixedIntData(count: 10000, deleteRatio: 0.2, insertRatio: 0.2, moveRatio: 0.2)
    let uuidData = makeMixedUUIDData(count: 10000, deleteRatio: 0.2, insertRatio: 0.2, moveRatio: 0.2)

    // --- Diff: IGListKit vs ListKit (pre-built data, algorithm only) ---

    let igOld = intData.old.map { NSNumber(value: $0) }
    let igNew = intData.new.map { NSNumber(value: $0) }
    let igTime = benchmark {
      _ = ListDiff(oldArray: igOld, newArray: igNew, option: .equality)
    }

    var lkOldSnap = DiffableDataSourceSnapshot<String, Int>()
    lkOldSnap.appendSections(["main"])
    lkOldSnap.appendItems(intData.old, toSection: "main")
    var lkNewSnap = DiffableDataSourceSnapshot<String, Int>()
    lkNewSnap.appendSections(["main"])
    lkNewSnap.appendItems(intData.new, toSection: "main")

    let lkDiffTime = benchmark {
      _ = SectionedDiff.diff(old: lkOldSnap, new: lkNewSnap)
    }

    // --- Snapshot build: Apple vs ListKit (BenchItem.ID) ---

    let appleTime = benchmark {
      var old = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
    }

    let lkBuildTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
    }

    // --- Full pipeline: ListKit build + diff (BenchItem.ID) ---

    let lkPipelineTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }

    print("""

      ═══ Mixed Operations — Moderate Churn 10k ═══
      \(intData.deleteCount) deleted, \(intData.insertCount) inserted, \(intData.moveCount) moved, \(intData.stableCount) stable

      Diff (pre-built data):
        IGListKit:  \(ms(igTime)) ms
        ListKit:    \(ms(lkDiffTime)) ms  (\(speedup(lkDiffTime, igTime)) faster)

      Snapshot Build (BenchItem.ID):
        Apple:      \(ms(appleTime)) ms
        ListKit:    \(ms(lkBuildTime)) ms  (\(speedup(lkBuildTime, appleTime)) faster)

      Full Pipeline — Build + Diff (BenchItem.ID):
        ListKit:    \(ms(lkPipelineTime)) ms

      """)

    #expect(
      lkBuildTime < appleTime,
      "ListKit (\(ms(lkBuildTime))) should be faster than Apple (\(ms(appleTime))) for mixed-ops snapshot build"
    )
  }

  @Test
  func heavyChurn10k() {
    let intData = makeMixedIntData(count: 10000, deleteRatio: 0.5, insertRatio: 0.5, moveRatio: 0.5)
    let uuidData = makeMixedUUIDData(count: 10000, deleteRatio: 0.5, insertRatio: 0.5, moveRatio: 0.5)

    // --- Diff: IGListKit vs ListKit ---

    let igOld = intData.old.map { NSNumber(value: $0) }
    let igNew = intData.new.map { NSNumber(value: $0) }
    let igTime = benchmark {
      _ = ListDiff(oldArray: igOld, newArray: igNew, option: .equality)
    }

    var lkOldSnap = DiffableDataSourceSnapshot<String, Int>()
    lkOldSnap.appendSections(["main"])
    lkOldSnap.appendItems(intData.old, toSection: "main")
    var lkNewSnap = DiffableDataSourceSnapshot<String, Int>()
    lkNewSnap.appendSections(["main"])
    lkNewSnap.appendItems(intData.new, toSection: "main")

    let lkDiffTime = benchmark {
      _ = SectionedDiff.diff(old: lkOldSnap, new: lkNewSnap)
    }

    // --- Snapshot build: Apple vs ListKit (BenchItem.ID) ---

    let appleTime = benchmark {
      var old = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
    }

    let lkBuildTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
    }

    // --- Full pipeline: ListKit build + diff (BenchItem.ID) ---

    let lkPipelineTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }

    print("""

      ═══ Mixed Operations — Heavy Churn 10k ═══
      \(intData.deleteCount) deleted, \(intData.insertCount) inserted, \(intData.moveCount) moved, \(intData.stableCount) stable

      Diff (pre-built data):
        IGListKit:  \(ms(igTime)) ms
        ListKit:    \(ms(lkDiffTime)) ms  (\(speedup(lkDiffTime, igTime)) faster)

      Snapshot Build (BenchItem.ID):
        Apple:      \(ms(appleTime)) ms
        ListKit:    \(ms(lkBuildTime)) ms  (\(speedup(lkBuildTime, appleTime)) faster)

      Full Pipeline — Build + Diff (BenchItem.ID):
        ListKit:    \(ms(lkPipelineTime)) ms

      """)

    #expect(
      lkBuildTime < appleTime,
      "ListKit (\(ms(lkBuildTime))) should be faster than Apple (\(ms(appleTime))) for heavy-churn snapshot build"
    )
  }

  @Test
  func moderateChurn50k() {
    let intData = makeMixedIntData(count: 50000, deleteRatio: 0.2, insertRatio: 0.2, moveRatio: 0.2)
    let uuidData = makeMixedUUIDData(count: 50000, deleteRatio: 0.2, insertRatio: 0.2, moveRatio: 0.2)

    // --- Diff: IGListKit vs ListKit ---

    let igOld = intData.old.map { NSNumber(value: $0) }
    let igNew = intData.new.map { NSNumber(value: $0) }
    let igTime = benchmark {
      _ = ListDiff(oldArray: igOld, newArray: igNew, option: .equality)
    }

    var lkOldSnap = DiffableDataSourceSnapshot<String, Int>()
    lkOldSnap.appendSections(["main"])
    lkOldSnap.appendItems(intData.old, toSection: "main")
    var lkNewSnap = DiffableDataSourceSnapshot<String, Int>()
    lkNewSnap.appendSections(["main"])
    lkNewSnap.appendItems(intData.new, toSection: "main")

    let lkDiffTime = benchmark {
      _ = SectionedDiff.diff(old: lkOldSnap, new: lkNewSnap)
    }

    // --- Snapshot build: Apple vs ListKit (BenchItem.ID) ---

    let appleTime = benchmark {
      var old = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
    }

    let lkBuildTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
    }

    // --- Full pipeline: ListKit build + diff (BenchItem.ID) ---

    let lkPipelineTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      old.appendSections(["main"])
      old.appendItems(uuidData.old, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, BenchItem.ID>()
      new.appendSections(["main"])
      new.appendItems(uuidData.new, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }

    print("""

      ═══ Mixed Operations — Moderate Churn 50k ═══
      \(intData.deleteCount) deleted, \(intData.insertCount) inserted, \(intData.moveCount) moved, \(intData.stableCount) stable

      Diff (pre-built data):
        IGListKit:  \(ms(igTime)) ms
        ListKit:    \(ms(lkDiffTime)) ms  (\(speedup(lkDiffTime, igTime)) faster)

      Snapshot Build (BenchItem.ID):
        Apple:      \(ms(appleTime)) ms
        ListKit:    \(ms(lkBuildTime)) ms  (\(speedup(lkBuildTime, appleTime)) faster)

      Full Pipeline — Build + Diff (BenchItem.ID):
        ListKit:    \(ms(lkPipelineTime)) ms

      """)

    #expect(
      lkBuildTime < appleTime,
      "ListKit (\(ms(lkBuildTime))) should be faster than Apple (\(ms(appleTime))) for 50k mixed-ops snapshot build"
    )
  }

  @Test @MainActor
  func moderateChurn10kApply() async {
    let uuidData = makeMixedUUIDData(count: 10000, deleteRatio: 0.2, insertRatio: 0.2, moveRatio: 0.2)

    // Pre-build snapshots (both frameworks)
    var appleOld = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
    appleOld.appendSections(["main"])
    appleOld.appendItems(uuidData.old, toSection: "main")
    var appleNew = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
    appleNew.appendSections(["main"])
    appleNew.appendItems(uuidData.new, toSection: "main")

    var lkOld = DiffableDataSourceSnapshot<String, BenchItem.ID>()
    lkOld.appendSections(["main"])
    lkOld.appendItems(uuidData.old, toSection: "main")
    var lkNew = DiffableDataSourceSnapshot<String, BenchItem.ID>()
    lkNew.appendSections(["main"])
    lkNew.appendItems(uuidData.new, toSection: "main")

    // --- Apple: apply (diff + batch update) ---

    let appleCv = makeCollectionView()
    let appleDs = UICollectionViewDiffableDataSource<String, BenchItem.ID>(collectionView: appleCv) { cv, ip, _ in
      cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip)
    }
    await appleDs.apply(appleOld, animatingDifferences: false)

    let appleTime = await benchmarkApply(
      setup: { await appleDs.applySnapshotUsingReloadData(appleOld) },
      work: { await appleDs.apply(appleNew, animatingDifferences: true) }
    )

    // --- ListKit: apply (diff + batch update) ---

    let lkCv = makeCollectionView()
    let lkDs = CollectionViewDiffableDataSource<String, BenchItem.ID>(collectionView: lkCv) { cv, ip, _ in
      cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip)
    }
    await lkDs.apply(lkOld, animatingDifferences: false)

    let lkTime = await benchmarkApply(
      setup: { await lkDs.applySnapshotUsingReloadData(lkOld) },
      work: { await lkDs.apply(lkNew, animatingDifferences: true) }
    )

    print("""

      ═══ Mixed Operations — Moderate Churn 10k (Apply) ═══
      \(uuidData.deleteCount) deleted, \(uuidData.insertCount) inserted, \(uuidData.moveCount) moved, \(uuidData.stableCount) stable

      Apply — diff + batch update (BenchItem.ID):
        Apple:    \(ms(appleTime)) ms
        ListKit:  \(ms(lkTime)) ms  (\(speedup(lkTime, appleTime)) faster)

      """)

    #expect(
      lkTime < appleTime,
      "ListKit apply (\(ms(lkTime))) should be faster than Apple apply (\(ms(appleTime))) for moderate-churn"
    )
  }

  @Test @MainActor
  func heavyChurn10kApply() async {
    let uuidData = makeMixedUUIDData(count: 10000, deleteRatio: 0.5, insertRatio: 0.5, moveRatio: 0.5)

    // Pre-build snapshots
    var appleOld = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
    appleOld.appendSections(["main"])
    appleOld.appendItems(uuidData.old, toSection: "main")
    var appleNew = NSDiffableDataSourceSnapshot<String, BenchItem.ID>()
    appleNew.appendSections(["main"])
    appleNew.appendItems(uuidData.new, toSection: "main")

    var lkOld = DiffableDataSourceSnapshot<String, BenchItem.ID>()
    lkOld.appendSections(["main"])
    lkOld.appendItems(uuidData.old, toSection: "main")
    var lkNew = DiffableDataSourceSnapshot<String, BenchItem.ID>()
    lkNew.appendSections(["main"])
    lkNew.appendItems(uuidData.new, toSection: "main")

    // --- Apple: apply (diff + batch update) ---

    let appleCv = makeCollectionView()
    let appleDs = UICollectionViewDiffableDataSource<String, BenchItem.ID>(collectionView: appleCv) { cv, ip, _ in
      cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip)
    }
    await appleDs.apply(appleOld, animatingDifferences: false)

    let appleTime = await benchmarkApply(
      setup: { await appleDs.applySnapshotUsingReloadData(appleOld) },
      work: { await appleDs.apply(appleNew, animatingDifferences: true) }
    )

    // --- ListKit: apply (diff + batch update) ---

    let lkCv = makeCollectionView()
    let lkDs = CollectionViewDiffableDataSource<String, BenchItem.ID>(collectionView: lkCv) { cv, ip, _ in
      cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip)
    }
    await lkDs.apply(lkOld, animatingDifferences: false)

    let lkTime = await benchmarkApply(
      setup: { await lkDs.applySnapshotUsingReloadData(lkOld) },
      work: { await lkDs.apply(lkNew, animatingDifferences: true) }
    )

    print("""

      ═══ Mixed Operations — Heavy Churn 10k (Apply) ═══
      \(uuidData.deleteCount) deleted, \(uuidData.insertCount) inserted, \(uuidData.moveCount) moved, \(uuidData.stableCount) stable

      Apply — diff + batch update (BenchItem.ID):
        Apple:    \(ms(appleTime)) ms
        ListKit:  \(ms(lkTime)) ms  (\(speedup(lkTime, appleTime)) faster)

      """)

    #expect(
      lkTime < appleTime,
      "ListKit apply (\(ms(lkTime))) should be faster than Apple apply (\(ms(appleTime))) for heavy-churn"
    )
  }
}
