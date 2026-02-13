@testable import ListKit
@testable import Lists
import Testing
import UIKit

@MainActor
struct OutlineListTests {
    @Test func flatItems() async {
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

    @Test func nestedItemsWithExpansion() async {
        let list = OutlineList<TextItem>()

        let child1 = OutlineItem(item: TextItem(text: "Child 1"))
        let child2 = OutlineItem(item: TextItem(text: "Child 2"))
        let parent = OutlineItem(item: TextItem(text: "Parent"), children: [child1, child2], isExpanded: true)

        await list.setItems([parent], animatingDifferences: false)

        let snapshot = list.snapshot()
        // Parent + 2 visible children
        #expect(snapshot.numberOfItems == 3)
    }

    @Test func collapsedHidesChildren() async {
        let list = OutlineList<TextItem>()

        let child1 = OutlineItem(item: TextItem(text: "Child 1"))
        let child2 = OutlineItem(item: TextItem(text: "Child 2"))
        let parent = OutlineItem(item: TextItem(text: "Parent"), children: [child1, child2], isExpanded: false)

        await list.setItems([parent], animatingDifferences: false)

        let snapshot = list.snapshot()
        // Only parent is visible; children are collapsed
        #expect(snapshot.numberOfItems == 1)
    }

    @Test func initWithCustomAppearance() {
        let list = OutlineList<TextItem>(appearance: .plain)
        #expect(list.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
    }
}
