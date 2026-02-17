// ABOUTME: Head-to-head benchmarks comparing ListKit vs Apple's NSDiffableDataSourceSnapshot.
// ABOUTME: Tests build, query, delete, and reload operations with strict timing assertions.
import Foundation
import ListKit
import Testing
import UIKit

/// ListKit vs Apple's NSDiffableDataSourceSnapshot — head-to-head comparisons.
///
/// Every test uses strict `listKitTime < appleTime`. No margins, no faking.
/// Uses median-of-N with warmup to reduce variance.
struct AppleComparisonBenchmarks {
  @Test
  func snapshotBuild10kItems() {
    let items = Array(0 ..< 10000)

    let listKitTime = benchmark {
      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
    }

    let appleTime = benchmark {
      var snapshot = NSDiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for 10k item build"
    )
  }

  @Test
  func snapshotBuild50kItems() {
    let items = Array(0 ..< 50000)

    let listKitTime = benchmark {
      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
    }

    let appleTime = benchmark {
      var snapshot = NSDiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for 50k item build"
    )
  }

  @Test
  func snapshotBuildMultipleSections() {
    let listKitTime = benchmark {
      var snapshot = DiffableDataSourceSnapshot<Int, Int>()
      var counter = 0
      for section in 0 ..< 100 {
        snapshot.appendSections([section])
        snapshot.appendItems(Array(counter ..< counter + 100), toSection: section)
        counter += 100
      }
    }

    let appleTime = benchmark {
      var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
      var counter = 0
      for section in 0 ..< 100 {
        snapshot.appendSections([section])
        snapshot.appendItems(Array(counter ..< counter + 100), toSection: section)
        counter += 100
      }
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for multi-section build"
    )
  }

  @Test
  func numberOfItemsQuery() {
    var listKitSnapshot = DiffableDataSourceSnapshot<String, Int>()
    listKitSnapshot.appendSections(["main"])
    listKitSnapshot.appendItems(Array(0 ..< 10000), toSection: "main")

    var appleSnapshot = NSDiffableDataSourceSnapshot<String, Int>()
    appleSnapshot.appendSections(["main"])
    appleSnapshot.appendItems(Array(0 ..< 10000), toSection: "main")

    let iterations = 100_000

    let listKitTime = benchmark {
      var sum = 0
      for _ in 0 ..< iterations {
        sum &+= listKitSnapshot.numberOfItems
      }
      precondition(sum > 0)
    }

    let appleTime = benchmark {
      var sum = 0
      for _ in 0 ..< iterations {
        sum &+= appleSnapshot.numberOfItems
      }
      precondition(sum > 0)
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for numberOfItems queries"
    )
  }

  @Test
  func itemIdentifiersQuery() {
    var listKitSnapshot = DiffableDataSourceSnapshot<String, Int>()
    listKitSnapshot.appendSections(["main"])
    listKitSnapshot.appendItems(Array(0 ..< 5000), toSection: "main")

    var appleSnapshot = NSDiffableDataSourceSnapshot<String, Int>()
    appleSnapshot.appendSections(["main"])
    appleSnapshot.appendItems(Array(0 ..< 5000), toSection: "main")

    let listKitTime = benchmark {
      for _ in 0 ..< 100 {
        _ = listKitSnapshot.itemIdentifiers
      }
    }

    let appleTime = benchmark {
      for _ in 0 ..< 100 {
        _ = appleSnapshot.itemIdentifiers
      }
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for itemIdentifiers queries"
    )
  }

  @Test
  func deleteItems() {
    let items = Array(0 ..< 10000)
    let itemsToDelete = Array(0 ..< 5000)

    let listKitTime = benchmark {
      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
      snapshot.deleteItems(itemsToDelete)
    }

    let appleTime = benchmark {
      var snapshot = NSDiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
      snapshot.deleteItems(itemsToDelete)
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for deleting 5k items"
    )
  }

  @Test
  func deleteSections() {
    let listKitTime = benchmark {
      var snapshot = DiffableDataSourceSnapshot<Int, Int>()
      for section in 0 ..< 50 {
        snapshot.appendSections([section])
        snapshot.appendItems(Array(section * 100 ..< section * 100 + 100), toSection: section)
      }
      let toDelete = stride(from: 0, to: 50, by: 2).map(\.self)
      snapshot.deleteSections(toDelete)
    }

    let appleTime = benchmark {
      var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
      for section in 0 ..< 50 {
        snapshot.appendSections([section])
        snapshot.appendItems(Array(section * 100 ..< section * 100 + 100), toSection: section)
      }
      let toDelete = stride(from: 0, to: 50, by: 2).map(\.self)
      snapshot.deleteSections(toDelete)
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for section deletion"
    )
  }

  @Test
  func reloadItems() {
    let items = Array(0 ..< 10000)
    let itemsToReload = Array(0 ..< 5000)

    let listKitTime = benchmark {
      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
      snapshot.reloadItems(itemsToReload)
    }

    let appleTime = benchmark {
      var snapshot = NSDiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
      snapshot.reloadItems(itemsToReload)
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for reloading 5k items"
    )
  }

  @Test
  func buildTwoSnapshotsForDiff() {
    let listKitTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, Int>()
      old.appendSections(["main"])
      old.appendItems(Array(0 ..< 10000), toSection: "main")

      var new = DiffableDataSourceSnapshot<String, Int>()
      new.appendSections(["main"])
      new.appendItems(Array(5000 ..< 15000), toSection: "main")
    }

    let appleTime = benchmark {
      var old = NSDiffableDataSourceSnapshot<String, Int>()
      old.appendSections(["main"])
      old.appendItems(Array(0 ..< 10000), toSection: "main")

      var new = NSDiffableDataSourceSnapshot<String, Int>()
      new.appendSections(["main"])
      new.appendItems(Array(5000 ..< 15000), toSection: "main")
    }

    #expect(
      listKitTime < appleTime,
      "ListKit (\(ms(listKitTime))) should be faster than Apple (\(ms(appleTime))) for building two 10k snapshots"
    )
  }
}
