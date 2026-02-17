// ABOUTME: Benchmarks measuring AnyItem type erasure overhead vs concrete ListDataSource.
// ABOUTME: Compares wrapping, snapshot building, diffing, and DSL paths for mixed types.
import Foundation
import Lists
import Testing
import UIKit
@testable import ListKit

/// Benchmarks measuring AnyItem (MixedListDataSource) overhead vs concrete ListDataSource path.
///
/// AnyItem adds type erasure cost: precomputed hash, ObjectIdentifier fast-reject equality,
/// and closure-based dequeue. These benchmarks quantify that overhead in Release configuration.
struct AnyItemBenchmarks {

  // MARK: Internal

  @Test
  func anyItemWrapping10k() {
    let items = (0 ..< 10000).map { ItemA(value: $0) }

    let wrapTime = benchmark {
      _ = items.map(AnyItem.init)
    }

    print("AnyItem wrap 10k: \(ms(wrapTime)) ms")
  }

  @Test
  func snapshotBuild10k() {
    let concreteItems = (0 ..< 10000).map { ItemA(value: $0) }
    let anyItems = concreteItems.map(AnyItem.init)

    let concreteTime = benchmark {
      var s = DiffableDataSourceSnapshot<String, ItemA>()
      s.appendSections(["main"])
      s.appendItems(concreteItems, toSection: "main")
    }

    let anyItemTime = benchmark {
      var s = DiffableDataSourceSnapshot<String, AnyItem>()
      s.appendSections(["main"])
      s.appendItems(anyItems, toSection: "main")
    }

    print("Snapshot build 10k — Concrete: \(ms(concreteTime)) ms | AnyItem: \(ms(anyItemTime)) ms")
  }

  @Test
  func snapshotBuild10kMixedTypes() {
    let items: [AnyItem] = (0 ..< 10000).map { i in
      i.isMultiple(of: 2) ? AnyItem(ItemA(value: i)) : AnyItem(ItemB(value: i))
    }

    let time = benchmark {
      var s = DiffableDataSourceSnapshot<String, AnyItem>()
      s.appendSections(["main"])
      s.appendItems(items, toSection: "main")
    }

    print("Snapshot build 10k mixed types: \(ms(time)) ms")
  }

  @Test
  func fullPipeline10k() {
    let concreteOld = (0 ..< 10000).map { ItemA(value: $0) }
    let concreteNew = (5000 ..< 15000).map { ItemA(value: $0) }
    let anyOld = concreteOld.map(AnyItem.init)
    let anyNew = concreteNew.map(AnyItem.init)

    let concreteTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, ItemA>()
      old.appendSections(["main"])
      old.appendItems(concreteOld, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, ItemA>()
      new.appendSections(["main"])
      new.appendItems(concreteNew, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }

    let anyItemTime = benchmark {
      var old = DiffableDataSourceSnapshot<String, AnyItem>()
      old.appendSections(["main"])
      old.appendItems(anyOld, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, AnyItem>()
      new.appendSections(["main"])
      new.appendItems(anyNew, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }

    print("Full pipeline 10k (50% overlap) — Concrete: \(ms(concreteTime)) ms | AnyItem: \(ms(anyItemTime)) ms")
  }

  @Test
  func fullPipeline10kCrossType() {
    // All old items are type A, all new items are type B — worst case for equality fast-reject
    let anyOld = (0 ..< 10000).map { AnyItem(ItemA(value: $0)) }
    let anyNew = (0 ..< 10000).map { AnyItem(ItemB(value: $0)) }

    let time = benchmark {
      var old = DiffableDataSourceSnapshot<String, AnyItem>()
      old.appendSections(["main"])
      old.appendItems(anyOld, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, AnyItem>()
      new.appendSections(["main"])
      new.appendItems(anyNew, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }

    print("Full pipeline 10k cross-type replace: \(ms(time)) ms")
  }

  @Test
  func dslBuild100Sections100Mixed() {
    let time = benchmark {
      _ = DiffableDataSourceSnapshot<Int, AnyItem> {
        for section in 0 ..< 100 {
          MixedSection(section) {
            (0 ..< 50).map { ItemA(value: section * 1000 + $0) }
            (0 ..< 50).map { ItemB(value: section * 1000 + 50 + $0) }
          }
        }
      }
    }

    print("DSL build 100x100 mixed: \(ms(time)) ms")
  }

  @Test
  func generateReport() {
    var lines = [String]()
    func log(_ s: String) {
      print(s)
      lines.append(s)
    }

    let concreteItems10k = (0 ..< 10000).map { ItemA(value: $0) }
    let anyItems10k = concreteItems10k.map(AnyItem.init)
    let mixedItems10k: [AnyItem] = (0 ..< 10000).map { i in
      i.isMultiple(of: 2) ? AnyItem(ItemA(value: i)) : AnyItem(ItemB(value: i))
    }

    // Wrap
    let wrapTime = benchmark { _ = concreteItems10k.map(AnyItem.init) }

    // Build
    let concreteBuild = benchmark {
      var s = DiffableDataSourceSnapshot<String, ItemA>()
      s.appendSections(["main"])
      s.appendItems(concreteItems10k, toSection: "main")
    }
    let anyBuild = benchmark {
      var s = DiffableDataSourceSnapshot<String, AnyItem>()
      s.appendSections(["main"])
      s.appendItems(anyItems10k, toSection: "main")
    }
    let mixedBuild = benchmark {
      var s = DiffableDataSourceSnapshot<String, AnyItem>()
      s.appendSections(["main"])
      s.appendItems(mixedItems10k, toSection: "main")
    }

    // Full pipeline
    let concreteOld = (0 ..< 10000).map { ItemA(value: $0) }
    let concreteNew = (5000 ..< 15000).map { ItemA(value: $0) }
    let anyOld = concreteOld.map(AnyItem.init)
    let anyNew = concreteNew.map(AnyItem.init)

    let concretePipeline = benchmark {
      var old = DiffableDataSourceSnapshot<String, ItemA>()
      old.appendSections(["main"])
      old.appendItems(concreteOld, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, ItemA>()
      new.appendSections(["main"])
      new.appendItems(concreteNew, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }
    let anyPipeline = benchmark {
      var old = DiffableDataSourceSnapshot<String, AnyItem>()
      old.appendSections(["main"])
      old.appendItems(anyOld, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, AnyItem>()
      new.appendSections(["main"])
      new.appendItems(anyNew, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }

    // Cross-type
    let crossOld = (0 ..< 10000).map { AnyItem(ItemA(value: $0)) }
    let crossNew = (0 ..< 10000).map { AnyItem(ItemB(value: $0)) }
    let crossPipeline = benchmark {
      var old = DiffableDataSourceSnapshot<String, AnyItem>()
      old.appendSections(["main"])
      old.appendItems(crossOld, toSection: "main")
      var new = DiffableDataSourceSnapshot<String, AnyItem>()
      new.appendSections(["main"])
      new.appendItems(crossNew, toSection: "main")
      _ = SectionedDiff.diff(old: old, new: new)
    }

    // DSL
    let dslMixed = benchmark {
      _ = DiffableDataSourceSnapshot<Int, AnyItem> {
        for section in 0 ..< 100 {
          MixedSection(section) {
            (0 ..< 50).map { ItemA(value: section * 1000 + $0) }
            (0 ..< 50).map { ItemB(value: section * 1000 + 50 + $0) }
          }
        }
      }
    }
    let dslConcrete = benchmark {
      _ = DiffableDataSourceSnapshot<Int, ItemA> {
        for section in 0 ..< 100 {
          SnapshotSection(section) {
            (0 ..< 100).map { ItemA(value: section * 1000 + $0) }
          }
        }
      }
    }

    func overhead(_ candidate: Duration, _ baseline: Duration) -> String {
      let ratio = Double(candidate.components.attoseconds) / Double(baseline.components.attoseconds)
      return String(format: "%.1fx", ratio)
    }

    log("### Lists: MixedListDataSource Overhead")
    log("")
    log("| Operation | Concrete | AnyItem | Overhead |")
    log("|:---|---:|---:|---:|")
    log("| Wrap 10k items | — | \(ms(wrapTime)) ms | — |")
    log("| Build 10k (single type) | \(ms(concreteBuild)) ms | \(ms(anyBuild)) ms | \(overhead(anyBuild, concreteBuild)) |")
    log("| Build 10k (mixed types) | \(ms(concreteBuild)) ms | \(ms(mixedBuild)) ms | \(overhead(mixedBuild, concreteBuild)) |")
    log("| DSL build 100x100 | \(ms(dslConcrete)) ms | \(ms(dslMixed)) ms | \(overhead(dslMixed, dslConcrete)) |")
    log(
      "| Diff 10k (50% overlap) | \(ms(concretePipeline)) ms | \(ms(anyPipeline)) ms | \(overhead(anyPipeline, concretePipeline)) |"
    )
    log("| Diff 10k (cross-type replace) | — | \(ms(crossPipeline)) ms | — |")

    let output = lines.joined(separator: "\n")
    print(output)
  }

  // MARK: Private

  private struct ItemA: CellViewModel {
    typealias Cell = UICollectionViewListCell

    let value: Int

    @MainActor
    func configure(_: UICollectionViewListCell) { }
  }

  private struct ItemB: CellViewModel {
    typealias Cell = UICollectionViewListCell

    let value: Int

    @MainActor
    func configure(_: UICollectionViewListCell) { }
  }

}
