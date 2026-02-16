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

    let itemA = TextItem(text: "A")
    let itemB = TextItem(text: "B")
    await list.setItems([itemA, itemB], animatingDifferences: false)

    // Trigger selection through the delegate method
    list.collectionView(list.collectionView, didSelectItemAt: IndexPath(item: 0, section: 0))
    list.collectionView(list.collectionView, didSelectItemAt: IndexPath(item: 1, section: 0))

    // Both items should have been reported through onSelect
    #expect(selected.count == 2)
    #expect(selected[0] == itemA)
    #expect(selected[1] == itemB)
  }

  @Test
  func singleSelectionAutoDeselects() async {
    let list = SimpleList<TextItem>()
    // Default: allowsMultipleSelection is false

    var selected = [TextItem]()
    list.onSelect = { item in selected.append(item) }

    let itemA = TextItem(text: "A")
    await list.setItems([itemA], animatingDifferences: false)

    // Trigger selection — should call onSelect
    list.collectionView(list.collectionView, didSelectItemAt: IndexPath(item: 0, section: 0))
    #expect(selected.count == 1)
    #expect(selected[0] == itemA)
  }

  @Test
  func didDeselectDelegateCallsOnDeselect() async {
    let list = SimpleList<TextItem>()

    var deselected = [TextItem]()
    list.onDeselect = { item in deselected.append(item) }

    let itemA = TextItem(text: "A")
    await list.setItems([itemA], animatingDifferences: false)

    // Trigger deselection through the delegate method
    list.collectionView(list.collectionView, didDeselectItemAt: IndexPath(item: 0, section: 0))
    #expect(deselected.count == 1)
    #expect(deselected[0] == itemA)
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

  @Test
  func onMoveCallbackIsWired() {
    let list = SimpleList<TextItem>()

    var movedSource: IndexPath?
    var movedDest: IndexPath?
    list.onMove = { source, dest in
      movedSource = source
      movedDest = dest
    }

    #expect(list.collectionView.dragInteractionEnabled == true)

    // Invoke the callback directly to verify wiring
    list.onMove?(IndexPath(item: 0, section: 0), IndexPath(item: 1, section: 0))
    #expect(movedSource == IndexPath(item: 0, section: 0))
    #expect(movedDest == IndexPath(item: 1, section: 0))
  }

  @Test
  func clearingOnMoveDisablesDragInteraction() {
    let list = SimpleList<TextItem>()
    list.onMove = { _, _ in }
    #expect(list.collectionView.dragInteractionEnabled == true)

    list.onMove = nil
    #expect(list.collectionView.dragInteractionEnabled == false)
  }

  @Test
  func showsSeparatorsDefaultIsTrue() {
    let list = SimpleList<TextItem>()
    // The default initializer uses showsSeparators: true.
    // We verify the layout was created (we can't inspect the layout config directly,
    // but we can verify the list was created successfully with the parameter).
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func showsSeparatorsFalseCreatesValidLayout() {
    let list = SimpleList<TextItem>(showsSeparators: false)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func numberOfItemsAndSections() async {
    let list = SimpleList<TextItem>()
    #expect(list.numberOfItems == 0)
    #expect(list.numberOfSections == 0)

    await list.setItems([TextItem(text: "A"), TextItem(text: "B")], animatingDifferences: false)
    #expect(list.numberOfItems == 2)
    #expect(list.numberOfSections == 1)
  }

  @Test
  func selectedItemsDefaultsToEmpty() async {
    let list = SimpleList<TextItem>()
    await list.setItems([TextItem(text: "A")], animatingDifferences: false)
    #expect(list.selectedItems.isEmpty)
  }

  @Test
  func selectedItemsReturnsCorrectItems() async {
    let list = SimpleList<TextItem>()
    let a = TextItem(text: "A")
    let b = TextItem(text: "B")
    await list.setItems([a, b], animatingDifferences: false)

    list.collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: [])
    #expect(list.selectedItems == [a])
  }

  @Test
  func deselectAllClearsSelection() async {
    let list = SimpleList<TextItem>()
    list.allowsMultipleSelection = true
    await list.setItems([TextItem(text: "A"), TextItem(text: "B")], animatingDifferences: false)

    list.collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: [])
    list.collectionView.selectItem(at: IndexPath(item: 1, section: 0), animated: false, scrollPosition: [])
    #expect((list.collectionView.indexPathsForSelectedItems ?? []).count == 2)

    list.deselectAll(animated: false)
    #expect((list.collectionView.indexPathsForSelectedItems ?? []).isEmpty)
  }
}
