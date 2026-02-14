import Testing
import UIKit
@testable import ListKit
@testable import Lists

@MainActor
struct SimpleListTests {
  @Test
  func initCreatesCollectionView() {
    let list = SimpleList<TextItem>()
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func setItemsPopulatesSnapshot() async {
    let list = SimpleList<TextItem>()
    let items = [
      TextItem(text: "A"),
      TextItem(text: "B"),
      TextItem(text: "C"),
    ]

    await list.setItems(items, animatingDifferences: false)

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfItems == 3)
    #expect(snapshot.numberOfSections == 1)
  }

  @Test
  func setItemsWithEmptyArrayClears() async {
    let list = SimpleList<TextItem>()

    await list.setItems([TextItem(text: "A")], animatingDifferences: false)
    #expect(list.snapshot().numberOfItems == 1)

    await list.setItems([], animatingDifferences: false)
    #expect(list.snapshot().numberOfItems == 0)
  }

  @Test
  func setItemsWithBuilder() async {
    let list = SimpleList<TextItem>()
    let a = TextItem(text: "A")
    let b = TextItem(text: "B")

    await list.setItems(animatingDifferences: false) {
      a
      b
    }

    #expect(list.snapshot().numberOfItems == 2)
  }

  @Test
  func initWithCustomAppearance() {
    let list = SimpleList<TextItem>(appearance: .insetGrouped)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }
}
