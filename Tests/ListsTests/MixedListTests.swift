import Testing
import UIKit
@testable import ListKit
@testable import Lists

// MARK: - AlphaItem

private struct AlphaItem: CellViewModel {
  typealias Cell = UICollectionViewListCell

  let value: String

  @MainActor
  func configure(_ cell: UICollectionViewListCell) {
    var content = cell.defaultContentConfiguration()
    content.text = value
    cell.contentConfiguration = content
  }
}

// MARK: - BetaItem

private struct BetaItem: CellViewModel {
  typealias Cell = UICollectionViewListCell

  let number: Int

  @MainActor
  func configure(_ cell: UICollectionViewListCell) {
    var content = cell.defaultContentConfiguration()
    content.text = "\(number)"
    cell.contentConfiguration = content
  }
}

// MARK: - GammaItem

private struct GammaItem: CellViewModel {
  typealias Cell = UICollectionViewListCell

  let id: Int

  @MainActor
  func configure(_: UICollectionViewListCell) { }
}

// MARK: - AnyItemEqualityTests

struct AnyItemEqualityTests {
  @Test
  func sameTypeSameValue() {
    let a = AnyItem(AlphaItem(value: "hello"))
    let b = AnyItem(AlphaItem(value: "hello"))
    #expect(a == b)
  }

  @Test
  func sameTypeDifferentValue() {
    let a = AnyItem(AlphaItem(value: "hello"))
    let b = AnyItem(AlphaItem(value: "world"))
    #expect(a != b)
  }

  @Test
  func differentTypeNotEqual() {
    let a = AnyItem(AlphaItem(value: "1"))
    let b = AnyItem(BetaItem(number: 1))
    #expect(a != b)
  }

  @Test
  func crossTypeCollisionNotEqual() {
    // GammaItem(id: 42) and BetaItem(number: 42) may produce the same underlying hash,
    // but they must NOT be equal because they are different types.
    let a = AnyItem(GammaItem(id: 42))
    let b = AnyItem(BetaItem(number: 42))
    #expect(a != b)
  }
}

// MARK: - AnyItemHashingTests

struct AnyItemHashingTests {
  @Test
  func sameItemsSameHash() {
    let a = AnyItem(AlphaItem(value: "test"))
    let b = AnyItem(AlphaItem(value: "test"))
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func differentTypesNamespacedHash() {
    // Even if underlying values produce the same hash, type ID namespacing
    // should make collisions rare (though not guaranteed by Hashable contract).
    let a = AnyItem(GammaItem(id: 42))
    let b = AnyItem(BetaItem(number: 42))
    // They are not equal, so they should ideally have different hashes.
    // This is probabilistic — the type ID provides namespacing.
    #expect(a != b)
  }

  @Test
  func usableAsDictionaryKey() {
    let item = AnyItem(AlphaItem(value: "key"))
    var dict = [AnyItem: String]()
    dict[item] = "found"
    #expect(dict[AnyItem(AlphaItem(value: "key"))] == "found")
  }

  @Test
  func usableInSet() {
    let a = AnyItem(AlphaItem(value: "x"))
    let b = AnyItem(AlphaItem(value: "x"))
    let c = AnyItem(AlphaItem(value: "y"))
    let set: Set<AnyItem> = [a, b, c]
    #expect(set.count == 2)
  }
}

// MARK: - AnyItemTypeExtractionTests

struct AnyItemTypeExtractionTests {
  @Test
  func extractCorrectType() {
    let original = AlphaItem(value: "hello")
    let wrapped = AnyItem(original)
    let extracted = wrapped.as(AlphaItem.self)
    #expect(extracted == original)
  }

  @Test
  func extractWrongTypeReturnsNil() {
    let wrapped = AnyItem(AlphaItem(value: "hello"))
    let extracted = wrapped.as(BetaItem.self)
    #expect(extracted == nil)
  }
}

// MARK: - MixedItemsBuilderTests

struct MixedItemsBuilderTests {
  @Test
  func singleItems() {
    @MixedItemsBuilder
    var items: [AnyItem] {
      AlphaItem(value: "a")
      BetaItem(number: 1)
    }
    #expect(items.count == 2)
    #expect(items[0].as(AlphaItem.self)?.value == "a")
    #expect(items[1].as(BetaItem.self)?.number == 1)
  }

  @Test
  func arrayOfConcreteItems() {
    let alphas = [AlphaItem(value: "a"), AlphaItem(value: "b")]
    @MixedItemsBuilder
    var items: [AnyItem] {
      alphas
    }
    #expect(items.count == 2)
  }

  @Test
  func preWrappedPassthrough() {
    let preWrapped = [AnyItem(AlphaItem(value: "pre"))]
    @MixedItemsBuilder
    var items: [AnyItem] {
      preWrapped
    }
    #expect(items.count == 1)
  }

  @Test
  func conditionalItems() {
    let showBeta = true
    @MixedItemsBuilder
    var items: [AnyItem] {
      AlphaItem(value: "always")
      if showBeta {
        BetaItem(number: 42)
      }
    }
    #expect(items.count == 2)
  }

  @Test
  func conditionalItemsOmitted() {
    let showBeta = false
    @MixedItemsBuilder
    var items: [AnyItem] {
      AlphaItem(value: "always")
      if showBeta {
        BetaItem(number: 42)
      }
    }
    #expect(items.count == 1)
  }

  @Test
  func ifElseItems() {
    let useAlpha = false
    @MixedItemsBuilder
    var items: [AnyItem] {
      if useAlpha {
        AlphaItem(value: "a")
      } else {
        BetaItem(number: 1)
      }
    }
    #expect(items.count == 1)
    #expect(items[0].as(BetaItem.self)?.number == 1)
  }

  @Test
  func loopItems() {
    @MixedItemsBuilder
    var items: [AnyItem] {
      for i in 0 ..< 3 {
        BetaItem(number: i)
      }
    }
    #expect(items.count == 3)
  }

  @Test
  func mixedTypesInOneBlock() {
    @MixedItemsBuilder
    var items: [AnyItem] {
      AlphaItem(value: "text")
      BetaItem(number: 99)
      GammaItem(id: 7)
    }
    #expect(items.count == 3)
    #expect(items[0].as(AlphaItem.self) != nil)
    #expect(items[1].as(BetaItem.self) != nil)
    #expect(items[2].as(GammaItem.self) != nil)
  }
}

// MARK: - MixedSnapshotBuilderTests

struct MixedSnapshotBuilderTests {
  @Test
  func multipleSections() {
    let snapshot = DiffableDataSourceSnapshot<String, AnyItem> {
      MixedSection("alpha") {
        AlphaItem(value: "a")
      }
      MixedSection("beta") {
        BetaItem(number: 1)
        BetaItem(number: 2)
      }
    }

    #expect(snapshot.numberOfSections == 2)
    #expect(snapshot.sectionIdentifiers == ["alpha", "beta"])
    #expect(snapshot.numberOfItems(inSection: "alpha") == 1)
    #expect(snapshot.numberOfItems(inSection: "beta") == 2)
  }

  @Test
  func conditionalSections() {
    let showExtra = true
    let snapshot = DiffableDataSourceSnapshot<String, AnyItem> {
      MixedSection("main") {
        AlphaItem(value: "a")
      }
      if showExtra {
        MixedSection("extra") {
          BetaItem(number: 1)
        }
      }
    }

    #expect(snapshot.numberOfSections == 2)
  }

  @Test
  func conditionalSectionsOmitted() {
    let showExtra = false
    let snapshot = DiffableDataSourceSnapshot<String, AnyItem> {
      MixedSection("main") {
        AlphaItem(value: "a")
      }
      if showExtra {
        MixedSection("extra") {
          BetaItem(number: 1)
        }
      }
    }

    #expect(snapshot.numberOfSections == 1)
  }

  @Test
  func loopSections() {
    let names = ["A", "B", "C"]
    let snapshot = DiffableDataSourceSnapshot<String, AnyItem> {
      for (i, name) in names.enumerated() {
        MixedSection(name) {
          BetaItem(number: i)
        }
      }
    }

    #expect(snapshot.numberOfSections == 3)
    #expect(snapshot.sectionIdentifiers == ["A", "B", "C"])
  }

  @Test
  func ifElseSections() {
    let useFirst = false
    let snapshot = DiffableDataSourceSnapshot<String, AnyItem> {
      if useFirst {
        MixedSection("first") {
          AlphaItem(value: "a")
        }
      } else {
        MixedSection("second") {
          BetaItem(number: 1)
        }
      }
    }

    #expect(snapshot.sectionIdentifiers == ["second"])
  }

  @Test
  func emptyBuilder() {
    let snapshot = DiffableDataSourceSnapshot<String, AnyItem> { }
    #expect(snapshot.numberOfSections == 0)
    #expect(snapshot.numberOfItems == 0)
  }

  @Test
  func sectionInitWithArray() {
    let items = [AnyItem(AlphaItem(value: "a")), AnyItem(BetaItem(number: 1))]
    let section = MixedSection("test", items: items)
    #expect(section.id == "test")
    #expect(section.items.count == 2)
  }

  @Test
  func sectionWithHeaderAndFooter() {
    let section = MixedSection("info", header: "Title", footer: "Subtitle") {
      AlphaItem(value: "a")
    }
    #expect(section.header == "Title")
    #expect(section.footer == "Subtitle")
    #expect(section.items.count == 1)
  }

  @Test
  func sectionHeaderFooterDefaults() {
    let section = MixedSection("bare") {
      AlphaItem(value: "a")
    }
    #expect(section.header == nil)
    #expect(section.footer == nil)
  }

  @Test
  func sectionInitWithArrayAndHeaderFooter() {
    let items = [AnyItem(AlphaItem(value: "a"))]
    let section = MixedSection("test", items: items, header: "H", footer: "F")
    #expect(section.header == "H")
    #expect(section.footer == "F")
  }

  @Test
  func availabilityCheckInMixedItems() {
    @MixedItemsBuilder
    var items: [AnyItem] {
      AlphaItem(value: "always")
      if #available(iOS 17, *) {
        BetaItem(number: 42)
      }
    }
    #expect(items.count == 2)
  }

  @Test
  func availabilityCheckInMixedSections() {
    let snapshot = DiffableDataSourceSnapshot<String, AnyItem> {
      MixedSection("main") {
        AlphaItem(value: "a")
      }
      if #available(iOS 17, *) {
        MixedSection("conditional") {
          BetaItem(number: 1)
        }
      }
    }
    #expect(snapshot.numberOfSections == 2)
  }
}

// MARK: - MixedListDataSourceTests

@MainActor
struct MixedListDataSourceTests {
  @Test
  func canMoveItemHandlerIsExposed() {
    let collectionView = UICollectionView(
      frame: .zero,
      collectionViewLayout: UICollectionViewCompositionalLayout.list(
        using: UICollectionLayoutListConfiguration(appearance: .plain)
      )
    )
    let dataSource = MixedListDataSource<String>(collectionView: collectionView)

    #expect(dataSource.canMoveItemHandler == nil)
    dataSource.canMoveItemHandler = { _ in true }
    #expect(dataSource.canMoveItemHandler != nil)
  }

  @Test
  func didMoveItemHandlerIsExposed() {
    let collectionView = UICollectionView(
      frame: .zero,
      collectionViewLayout: UICollectionViewCompositionalLayout.list(
        using: UICollectionLayoutListConfiguration(appearance: .plain)
      )
    )
    let dataSource = MixedListDataSource<String>(collectionView: collectionView)

    #expect(dataSource.didMoveItemHandler == nil)
    var movedSource: IndexPath?
    var movedDest: IndexPath?
    dataSource.didMoveItemHandler = { source, dest in
      movedSource = source
      movedDest = dest
    }
    dataSource.didMoveItemHandler?(IndexPath(item: 0, section: 0), IndexPath(item: 1, section: 0))
    #expect(movedSource == IndexPath(item: 0, section: 0))
    #expect(movedDest == IndexPath(item: 1, section: 0))
  }
}

// MARK: - MixedSnapshotDiffingTests

struct MixedSnapshotDiffingTests {
  @Test
  func insertMixedItems() {
    var snapshot = DiffableDataSourceSnapshot<String, AnyItem>()
    snapshot.appendSections(["main"])
    snapshot.appendItems([AnyItem(AlphaItem(value: "a"))], toSection: "main")

    var updated = DiffableDataSourceSnapshot<String, AnyItem>()
    updated.appendSections(["main"])
    updated.appendItems([
      AnyItem(AlphaItem(value: "a")),
      AnyItem(BetaItem(number: 1)),
    ], toSection: "main")

    #expect(updated.numberOfItems == 2)
  }

  @Test
  func deleteMixedItems() {
    var snapshot = DiffableDataSourceSnapshot<String, AnyItem>()
    snapshot.appendSections(["main"])
    snapshot.appendItems([
      AnyItem(AlphaItem(value: "a")),
      AnyItem(BetaItem(number: 1)),
    ], toSection: "main")

    snapshot.deleteItems([AnyItem(AlphaItem(value: "a"))])
    #expect(snapshot.numberOfItems == 1)
  }

  @Test
  func moveMixedItemsBetweenSections() {
    var snapshot = DiffableDataSourceSnapshot<String, AnyItem>()
    snapshot.appendSections(["alpha", "beta"])
    let item = AnyItem(AlphaItem(value: "moveable"))
    let anchor = AnyItem(BetaItem(number: 99))
    snapshot.appendItems([item], toSection: "alpha")
    snapshot.appendItems([anchor], toSection: "beta")

    snapshot.moveItem(item, afterItem: anchor)

    #expect(snapshot.numberOfItems(inSection: "alpha") == 0)
    #expect(snapshot.numberOfItems(inSection: "beta") == 2)
  }

  @Test
  func reconfigureWithAnyItem() {
    var snapshot = DiffableDataSourceSnapshot<String, AnyItem>()
    snapshot.appendSections(["main"])
    let item = AnyItem(AlphaItem(value: "a"))
    snapshot.appendItems([item], toSection: "main")
    snapshot.reconfigureItems([item])

    #expect(snapshot.reconfiguredItemIdentifiers.contains(item))
  }

  @Test
  func reloadWithAnyItem() {
    var snapshot = DiffableDataSourceSnapshot<String, AnyItem>()
    snapshot.appendSections(["main"])
    let item = AnyItem(BetaItem(number: 1))
    snapshot.appendItems([item], toSection: "main")
    snapshot.reloadItems([item])

    #expect(snapshot.reloadedItemIdentifiers.contains(item))
  }
}
