// ABOUTME: Benchmarks comparing ListKit's Heckel diff vs IGListKit's Obj-C++ ListDiff.
// ABOUTME: Tests 10k/50k elements, no-change, and shuffle scenarios.
import Foundation
import IGListDiffKit
import Testing
@testable import ListKit

/// Benchmarks comparing ListKit's diff against IGListKit's diff algorithm.
///
/// Both libraries implement O(n) Heckel diff. IGListKit's `ListDiff` operates on
/// flat `NSArray<id<IGListDiffable>>` (Obj-C++). ListKit uses Swift generics with
/// `Hashable` value types.
///
/// Both sides pre-build their data structures before the timed block so only
/// the diff algorithm itself is measured.
struct IGListDiffBenchmarks {
  @Test
  func diff10kElements() {
    let old = (0 ..< 10000).map { NSNumber(value: $0) }
    let new = (5000 ..< 15000).map { NSNumber(value: $0) }

    let igTime = benchmark {
      _ = ListDiff(oldArray: old, newArray: new, option: .equality)
    }

    var oldSnap = DiffableDataSourceSnapshot<String, Int>()
    oldSnap.appendSections(["main"])
    oldSnap.appendItems(Array(0 ..< 10000), toSection: "main")
    var newSnap = DiffableDataSourceSnapshot<String, Int>()
    newSnap.appendSections(["main"])
    newSnap.appendItems(Array(5000 ..< 15000), toSection: "main")

    let lkTime = benchmark {
      _ = SectionedDiff.diff(old: oldSnap, new: newSnap)
    }

    print("Diff 10k — IGListKit: \(ms(igTime)) ms | ListKit: \(ms(lkTime)) ms")
  }

  @Test
  func diff50kElements() {
    let old = (0 ..< 50000).map { NSNumber(value: $0) }
    let new = (25000 ..< 75000).map { NSNumber(value: $0) }

    let igTime = benchmark {
      _ = ListDiff(oldArray: old, newArray: new, option: .equality)
    }

    var oldSnap = DiffableDataSourceSnapshot<String, Int>()
    oldSnap.appendSections(["main"])
    oldSnap.appendItems(Array(0 ..< 50000), toSection: "main")
    var newSnap = DiffableDataSourceSnapshot<String, Int>()
    newSnap.appendSections(["main"])
    newSnap.appendItems(Array(25000 ..< 75000), toSection: "main")

    let lkTime = benchmark {
      _ = SectionedDiff.diff(old: oldSnap, new: newSnap)
    }

    print("Diff 50k — IGListKit: \(ms(igTime)) ms | ListKit: \(ms(lkTime)) ms")
  }

  @Test
  func diffNoChange10k() {
    let items = (0 ..< 10000).map { NSNumber(value: $0) }

    let igTime = benchmark {
      _ = ListDiff(oldArray: items, newArray: items, option: .equality)
    }

    var oldSnap = DiffableDataSourceSnapshot<String, Int>()
    oldSnap.appendSections(["main"])
    oldSnap.appendItems(Array(0 ..< 10000), toSection: "main")
    var newSnap = DiffableDataSourceSnapshot<String, Int>()
    newSnap.appendSections(["main"])
    newSnap.appendItems(Array(0 ..< 10000), toSection: "main")

    let lkTime = benchmark {
      _ = SectionedDiff.diff(old: oldSnap, new: newSnap)
    }

    print("Diff no-change 10k — IGListKit: \(ms(igTime)) ms | ListKit: \(ms(lkTime)) ms")
  }

  @Test
  func diffShuffle10k() {
    let old = (0 ..< 10000).map { NSNumber(value: $0) }
    var shuffled = old
    for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
      let j = i * 7 % (i + 1)
      shuffled.swapAt(i, j)
    }

    let igTime = benchmark {
      _ = ListDiff(oldArray: old, newArray: shuffled, option: .equality)
    }

    let oldInts = Array(0 ..< 10000)
    var shuffledInts = oldInts
    for i in stride(from: shuffledInts.count - 1, through: 1, by: -1) {
      let j = i * 7 % (i + 1)
      shuffledInts.swapAt(i, j)
    }

    var oldSnap = DiffableDataSourceSnapshot<String, Int>()
    oldSnap.appendSections(["main"])
    oldSnap.appendItems(oldInts, toSection: "main")
    var newSnap = DiffableDataSourceSnapshot<String, Int>()
    newSnap.appendSections(["main"])
    newSnap.appendItems(shuffledInts, toSection: "main")

    let lkTime = benchmark {
      _ = SectionedDiff.diff(old: oldSnap, new: newSnap)
    }

    print("Diff shuffle 10k — IGListKit: \(ms(igTime)) ms | ListKit: \(ms(lkTime)) ms")
  }
}
