@testable import ListKit
import Testing

struct SnapshotTests {
    @Test func emptySnapshot() {
        let snapshot = DiffableDataSourceSnapshot<String, Int>()
        #expect(snapshot.numberOfSections == 0)
        #expect(snapshot.numberOfItems == 0)
        #expect(snapshot.sectionIdentifiers.isEmpty)
        #expect(snapshot.itemIdentifiers.isEmpty)
    }

    @Test func appendSections() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B", "C"])
        #expect(snapshot.numberOfSections == 3)
        #expect(snapshot.sectionIdentifiers == ["A", "B", "C"])
    }

    @Test func appendItems() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A"])
        snapshot.appendItems([1, 2, 3], toSection: "A")
        #expect(snapshot.numberOfItems == 3)
        #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 2, 3])
    }

    @Test func appendItemsToLastSection() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B"])
        snapshot.appendItems([1, 2])
        #expect(snapshot.itemIdentifiers(inSection: "B") == [1, 2])
    }

    @Test func insertSectionsBeforeAndAfter() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "C"])
        snapshot.insertSections(["B"], beforeSection: "C")
        #expect(snapshot.sectionIdentifiers == ["A", "B", "C"])
        snapshot.insertSections(["D"], afterSection: "C")
        #expect(snapshot.sectionIdentifiers == ["A", "B", "C", "D"])
    }

    @Test func insertItemsBeforeAndAfter() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A"])
        snapshot.appendItems([1, 3], toSection: "A")
        snapshot.insertItems([2], beforeItem: 3)
        #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 2, 3])
        snapshot.insertItems([4], afterItem: 3)
        #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 2, 3, 4])
    }

    @Test func deleteSections() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B", "C"])
        snapshot.appendItems([1, 2], toSection: "B")
        snapshot.deleteSections(["B"])
        #expect(snapshot.numberOfSections == 2)
        #expect(snapshot.sectionIdentifiers == ["A", "C"])
        #expect(snapshot.sectionIdentifier(containingItem: 1) == nil)
    }

    @Test func deleteItems() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A"])
        snapshot.appendItems([1, 2, 3], toSection: "A")
        snapshot.deleteItems([2])
        #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 3])
        #expect(snapshot.numberOfItems == 2)
    }

    @Test func deleteAllItems() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B"])
        snapshot.appendItems([1, 2], toSection: "A")
        snapshot.appendItems([3, 4], toSection: "B")
        snapshot.deleteAllItems()
        #expect(snapshot.numberOfItems == 0)
        #expect(snapshot.numberOfSections == 2)
    }

    @Test func moveSection() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B", "C"])
        snapshot.moveSection("C", beforeSection: "A")
        #expect(snapshot.sectionIdentifiers == ["C", "A", "B"])
    }

    @Test func moveSectionAfter() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B", "C"])
        snapshot.moveSection("A", afterSection: "C")
        #expect(snapshot.sectionIdentifiers == ["B", "C", "A"])
    }

    @Test func moveItem() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A"])
        snapshot.appendItems([1, 2, 3], toSection: "A")
        snapshot.moveItem(3, beforeItem: 1)
        #expect(snapshot.itemIdentifiers(inSection: "A") == [3, 1, 2])
    }

    @Test func moveItemCrossSection() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B"])
        snapshot.appendItems([1, 2], toSection: "A")
        snapshot.appendItems([3], toSection: "B")
        snapshot.moveItem(2, afterItem: 3)
        #expect(snapshot.itemIdentifiers(inSection: "A") == [1])
        #expect(snapshot.itemIdentifiers(inSection: "B") == [3, 2])
        #expect(snapshot.sectionIdentifier(containingItem: 2) == "B")
    }

    @Test func sectionContainingItem() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B"])
        snapshot.appendItems([1], toSection: "A")
        snapshot.appendItems([2], toSection: "B")
        #expect(snapshot.sectionIdentifier(containingItem: 1) == "A")
        #expect(snapshot.sectionIdentifier(containingItem: 2) == "B")
        #expect(snapshot.sectionIdentifier(containingItem: 3) == nil)
    }

    @Test func indexOfItemAndSection() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B"])
        snapshot.appendItems([1, 2], toSection: "A")
        snapshot.appendItems([3], toSection: "B")
        #expect(snapshot.index(ofSection: "A") == 0)
        #expect(snapshot.index(ofSection: "B") == 1)
        #expect(snapshot.index(ofItem: 1) == 0)
        #expect(snapshot.index(ofItem: 2) == 1)
        #expect(snapshot.index(ofItem: 3) == 2)
    }

    @Test func reloadAndReconfigure() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A"])
        snapshot.appendItems([1, 2, 3], toSection: "A")
        snapshot.reloadItems([1, 2])
        snapshot.reconfigureItems([3])
        snapshot.reloadSections(["A"])
        #expect(snapshot.reloadedItemIdentifiers == Set([1, 2]))
        #expect(snapshot.reconfiguredItemIdentifiers == Set([3]))
        #expect(snapshot.reloadedSectionIdentifiers == Set(["A"]))
    }

    @Test func numberOfItemsInSection() {
        var snapshot = DiffableDataSourceSnapshot<String, Int>()
        snapshot.appendSections(["A", "B"])
        snapshot.appendItems([1, 2, 3], toSection: "A")
        snapshot.appendItems([4], toSection: "B")
        #expect(snapshot.numberOfItems(inSection: "A") == 3)
        #expect(snapshot.numberOfItems(inSection: "B") == 1)
    }

    @Test func sendableConformance() {
        let snapshot = DiffableDataSourceSnapshot<String, Int>()
        let _: any Sendable = snapshot
    }
}
