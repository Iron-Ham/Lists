// ABOUTME: Benchmarks comparing ListKit snapshot construction vs ReactiveCollectionsKit.
// ABOUTME: Measures model build overhead and type erasure cost across various data sizes.
import Foundation
import ListKit
import ReactiveCollectionsKit
import Testing
import UIKit

/// Benchmarks comparing ListKit's model construction against ReactiveCollectionsKit.
///
/// ReactiveCollectionsKit wraps `NSDiffableDataSourceSnapshot<AnyHashable, AnyHashable>` internally,
/// adding type-erased `CollectionViewModel` → `SectionViewModel` → `AnyCellViewModel` layers.
/// These benchmarks measure the overhead of that abstraction vs ListKit's direct snapshot API.
struct ReactiveCollectionsKitBenchmarks {
  struct BenchCell: CellViewModel {
    typealias CellType = UICollectionViewCell

    let id: UniqueIdentifier
    let value: Int

    var registration: ViewRegistration {
      ViewRegistration(
        reuseIdentifier: "BenchCell",
        viewType: .cell,
        method: .viewClass(UICollectionViewCell.self)
      )
    }

    static func ==(lhs: BenchCell, rhs: BenchCell) -> Bool {
      lhs.id == rhs.id && lhs.value == rhs.value
    }

    @MainActor
    func configure(cell _: UICollectionViewCell) { }

    func hash(into hasher: inout Hasher) {
      hasher.combine(id)
      hasher.combine(value)
    }
  }

  @Test
  func modelConstruction10k() {
    let cells = (0 ..< 10000).map { i in
      BenchCell(id: AnyHashable(i), value: i)
    }

    let rcTime = benchmark {
      let section = SectionViewModel(id: "main", cells: cells)
      _ = CollectionViewModel(id: "bench", sections: [section])
    }

    let lkTime = benchmark {
      var snap = DiffableDataSourceSnapshot<String, Int>()
      snap.appendSections(["main"])
      snap.appendItems(Array(0 ..< 10000), toSection: "main")
    }

    let apTime = benchmark {
      var snap = NSDiffableDataSourceSnapshot<String, Int>()
      snap.appendSections(["main"])
      snap.appendItems(Array(0 ..< 10000), toSection: "main")
    }

    print("Model build 10k — RC: \(ms(rcTime)) ms | ListKit: \(ms(lkTime)) ms | Apple: \(ms(apTime)) ms")
  }

  @Test
  func modelConstruction50k() {
    let cells = (0 ..< 50000).map { i in
      BenchCell(id: AnyHashable(i), value: i)
    }

    let rcTime = benchmark {
      let section = SectionViewModel(id: "main", cells: cells)
      _ = CollectionViewModel(id: "bench", sections: [section])
    }

    let lkTime = benchmark {
      var snap = DiffableDataSourceSnapshot<String, Int>()
      snap.appendSections(["main"])
      snap.appendItems(Array(0 ..< 50000), toSection: "main")
    }

    print("Model build 50k — RC: \(ms(rcTime)) ms | ListKit: \(ms(lkTime)) ms")
  }

  @Test
  func modelConstruction100Sections() {
    let sectionCells = (0 ..< 100).map { sec in
      (0 ..< 100).map { i in
        BenchCell(id: AnyHashable(sec * 100 + i), value: sec * 100 + i)
      }
    }

    let rcTime = benchmark {
      let sections = sectionCells.enumerated().map { sec, cells in
        SectionViewModel(id: AnyHashable(sec), cells: cells)
      }
      _ = CollectionViewModel(id: "bench", sections: sections)
    }

    let lkTime = benchmark {
      var snap = DiffableDataSourceSnapshot<Int, Int>()
      var c = 0
      for sec in 0 ..< 100 {
        snap.appendSections([sec])
        snap.appendItems(Array(c ..< c + 100), toSection: sec)
        c += 100
      }
    }

    let apTime = benchmark {
      var snap = NSDiffableDataSourceSnapshot<Int, Int>()
      var c = 0
      for sec in 0 ..< 100 {
        snap.appendSections([sec])
        snap.appendItems(Array(c ..< c + 100), toSection: sec)
        c += 100
      }
    }

    print("Model build 100x100 — RC: \(ms(rcTime)) ms | ListKit: \(ms(lkTime)) ms | Apple: \(ms(apTime)) ms")
  }

  @Test
  func typeErasureOverhead10k() {
    let cells = (0 ..< 10000).map { i in
      BenchCell(id: AnyHashable(i), value: i)
    }

    // Measure just the type erasure step (eraseToAnyViewModel)
    let eraseTime = benchmark {
      _ = cells.map { $0.eraseToAnyViewModel() }
    }

    print("Type erasure 10k cells: \(ms(eraseTime)) ms")
  }
}
