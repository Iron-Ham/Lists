import Testing
import UIKit
@testable import ListKit
@testable import Lists

@MainActor
struct OutlineListTests {
  @Test
  func flatItems() async {
    let list = OutlineList<TextItem>()
    let items = [
      OutlineItem(item: TextItem(text: "A")),
      OutlineItem(item: TextItem(text: "B")),
      OutlineItem(item: TextItem(text: "C")),
    ]

    await list.setItems(items, animatingDifferences: false)

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfItems == 3)
  }

  @Test
  func nestedItemsWithExpansion() async {
    let list = OutlineList<TextItem>()

    let child1 = OutlineItem(item: TextItem(text: "Child 1"))
    let child2 = OutlineItem(item: TextItem(text: "Child 2"))
    let parent = OutlineItem(item: TextItem(text: "Parent"), children: [child1, child2], isExpanded: true)

    await list.setItems([parent], animatingDifferences: false)

    let snapshot = list.snapshot()
    // Parent + 2 visible children
    #expect(snapshot.numberOfItems == 3)
  }

  @Test
  func collapsedHidesChildren() async {
    let list = OutlineList<TextItem>()

    let child1 = OutlineItem(item: TextItem(text: "Child 1"))
    let child2 = OutlineItem(item: TextItem(text: "Child 2"))
    let parent = OutlineItem(item: TextItem(text: "Parent"), children: [child1, child2], isExpanded: false)

    await list.setItems([parent], animatingDifferences: false)

    let snapshot = list.snapshot()
    // Only parent is visible; children are collapsed
    #expect(snapshot.numberOfItems == 1)
  }

  @Test
  func initWithCustomAppearance() {
    let list = OutlineList<TextItem>(appearance: .plain)
    #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
  }

  @Test
  func setItemsThenSetAgainUpdatesCorrectly() async {
    let list = OutlineList<TextItem>()

    // First call creates the section and populates items
    let items1 = [
      OutlineItem(item: TextItem(text: "A")),
      OutlineItem(item: TextItem(text: "B")),
    ]
    await list.setItems(items1, animatingDifferences: false)
    #expect(list.snapshot().numberOfItems == 2)

    // Second call should update items without crashing (section already exists)
    let items2 = [
      OutlineItem(item: TextItem(text: "C"))
    ]
    await list.setItems(items2, animatingDifferences: false)
    #expect(list.snapshot().numberOfItems == 1)
  }

  @Test
  func setEmptyItemsThenPopulate() async {
    let list = OutlineList<TextItem>()

    // Start with empty
    await list.setItems([], animatingDifferences: false)
    #expect(list.snapshot().numberOfItems == 0)

    // Then populate
    let items = [
      OutlineItem(item: TextItem(text: "A"))
    ]
    await list.setItems(items, animatingDifferences: false)
    #expect(list.snapshot().numberOfItems == 1)
  }

  @Test
  func cancelledSetItemsDoesNotCrash() async {
    let list = OutlineList<TextItem>()

    await list.setItems([OutlineItem(item: TextItem(text: "A"))], animatingDifferences: false)

    let task = Task {
      await list.setItems([OutlineItem(item: TextItem(text: "B"))], animatingDifferences: false)
    }
    task.cancel()
    await task.value

    // Should be in a consistent state
    let snapshot = list.snapshot()
    #expect(snapshot.numberOfSections <= 1)
  }

  @Test
  func expandItemProgrammatically() async {
    let list = OutlineList<TextItem>()
    let parent = TextItem(text: "Parent")
    let child1 = TextItem(text: "Child 1")
    let child2 = TextItem(text: "Child 2")

    let items = [
      OutlineItem(item: parent, children: [
        OutlineItem(item: child1),
        OutlineItem(item: child2),
      ], isExpanded: false)
    ]

    await list.setItems(items, animatingDifferences: false)
    #expect(list.snapshot().numberOfItems == 1)
    #expect(list.isExpanded(parent) == false)

    await list.expand(parent, animated: false)
    #expect(list.snapshot().numberOfItems == 3)
    #expect(list.isExpanded(parent) == true)
  }

  @Test
  func collapseItemProgrammatically() async {
    let list = OutlineList<TextItem>()
    let parent = TextItem(text: "Parent")
    let child = TextItem(text: "Child")

    let items = [
      OutlineItem(item: parent, children: [
        OutlineItem(item: child)
      ], isExpanded: true)
    ]

    await list.setItems(items, animatingDifferences: false)
    #expect(list.snapshot().numberOfItems == 2)
    #expect(list.isExpanded(parent) == true)

    await list.collapse(parent, animated: false)
    #expect(list.snapshot().numberOfItems == 1)
    #expect(list.isExpanded(parent) == false)
  }

  @Test
  func expandNonExistentItemIsNoOp() async {
    let list = OutlineList<TextItem>()
    let parent = TextItem(text: "Parent")
    let child = TextItem(text: "Child")

    await list.setItems([
      OutlineItem(item: parent, children: [OutlineItem(item: child)], isExpanded: false)
    ], animatingDifferences: false)

    // Expanding an item not in the snapshot should not crash or change state
    await list.expand(TextItem(text: "Nonexistent"), animated: false)
    #expect(list.snapshot().numberOfItems == 1)
    #expect(list.isExpanded(parent) == false)
  }

  @Test
  func collapseNonExistentItemIsNoOp() async {
    let list = OutlineList<TextItem>()
    let parent = TextItem(text: "Parent")
    let child = TextItem(text: "Child")

    await list.setItems([
      OutlineItem(item: parent, children: [OutlineItem(item: child)], isExpanded: true)
    ], animatingDifferences: false)

    await list.collapse(TextItem(text: "Nonexistent"), animated: false)
    #expect(list.snapshot().numberOfItems == 2)
    #expect(list.isExpanded(parent) == true)
  }

  @Test
  func selectedItemsReturnsCorrectItems() async {
    let list = OutlineList<TextItem>()
    let a = TextItem(text: "A")
    let b = TextItem(text: "B")
    await list.setItems([
      OutlineItem(item: a),
      OutlineItem(item: b),
    ], animatingDifferences: false)

    list.collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: [])
    #expect(list.selectedItems == [a])
  }

  @Test
  func isExpandedReturnsFalseWhenNoSnapshot() {
    let list = OutlineList<TextItem>()
    #expect(list.isExpanded(TextItem(text: "Nonexistent")) == false)
  }

  @Test
  func numberOfItemsAndSections() async {
    let list = OutlineList<TextItem>()
    await list.setItems([
      OutlineItem(item: TextItem(text: "A")),
      OutlineItem(item: TextItem(text: "B")),
    ], animatingDifferences: false)

    #expect(list.numberOfItems == 2)
    #expect(list.numberOfSections == 1)
  }

  @Test
  func selectedItemsReturnsEmpty() async {
    let list = OutlineList<TextItem>()
    await list.setItems([OutlineItem(item: TextItem(text: "A"))], animatingDifferences: false)
    #expect(list.selectedItems.isEmpty)
  }

  @Test
  func deselectAllClearsSelection() async {
    let list = OutlineList<TextItem>()
    list.allowsMultipleSelection = true
    await list.setItems([
      OutlineItem(item: TextItem(text: "A")),
      OutlineItem(item: TextItem(text: "B")),
    ], animatingDifferences: false)

    list.collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: [])
    list.collectionView.selectItem(at: IndexPath(item: 1, section: 0), animated: false, scrollPosition: [])
    #expect((list.collectionView.indexPathsForSelectedItems ?? []).count == 2)

    list.deselectAll(animated: false)
    #expect((list.collectionView.indexPathsForSelectedItems ?? []).isEmpty)
  }

  @Test
  func outlineItemIsIdentifiable() {
    let item = OutlineItem(item: TextItem(text: "A"))
    #expect(item.id == item.item)
    let _: any Identifiable = item
  }
}
