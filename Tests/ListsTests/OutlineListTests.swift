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
}
