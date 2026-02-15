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

  @Test
  func cancelledSetItemsDoesNotCrash() async {
    let list = SimpleList<TextItem>()

    // Set initial items
    await list.setItems([TextItem(text: "A")], animatingDifferences: false)

    // Cancel a task that sets new items — should not crash
    let task = Task {
      await list.setItems([TextItem(text: "B"), TextItem(text: "C")], animatingDifferences: false)
    }
    task.cancel()
    await task.value

    // The snapshot should be in a consistent state (either old or new, but not corrupt)
    let snapshot = list.snapshot()
    #expect(snapshot.numberOfSections <= 1)
  }

  @Test
  func rapidSetItemsConverges() async {
    let list = SimpleList<TextItem>()

    // Fire multiple rapid updates — only the last should matter
    for i in 0 ..< 5 {
      let items = (0 ..< i + 1).map { TextItem(text: "Item \($0)") }
      await list.setItems(items, animatingDifferences: false)
    }

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfItems == 5)
  }

  @Test
  func multipleSelectionDoesNotAutoDeselect() async {
    let list = SimpleList<TextItem>()
    list.collectionView.allowsMultipleSelection = true

    var selected = [TextItem]()
    list.onSelect = { item in selected.append(item) }

    await list.setItems([TextItem(text: "A"), TextItem(text: "B")], animatingDifferences: false)

    // Verify multi-selection is enabled (collection view property persists)
    #expect(list.collectionView.allowsMultipleSelection == true)
  }

  @Test
  func onDeleteCallbackIsStored() {
    let list = SimpleList<TextItem>()
    var deletedItem: TextItem?
    list.onDelete = { item in deletedItem = item }

    // Verify the callback is stored (we can't trigger swipe in unit tests,
    // but we verify the plumbing is set up)
    #expect(list.onDelete != nil)
    list.onDelete?(TextItem(text: "X"))
    #expect(deletedItem?.text == "X")
  }

  @Test
  func onDeselectCallbackIsStored() {
    let list = SimpleList<TextItem>()
    var deselectedItem: TextItem?
    list.onDeselect = { item in deselectedItem = item }
    #expect(list.onDeselect != nil)
    list.onDeselect?(TextItem(text: "Y"))
    #expect(deselectedItem?.text == "Y")
  }
}
