import Testing
@testable import ListKit

struct SnapshotTests {
  @Test
  func emptySnapshot() {
    let snapshot = DiffableDataSourceSnapshot<String, Int>()
    #expect(snapshot.numberOfSections == 0)
    #expect(snapshot.numberOfItems == 0)
    #expect(snapshot.sectionIdentifiers.isEmpty)
    #expect(snapshot.itemIdentifiers.isEmpty)
  }

  @Test
  func appendSections() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B", "C"])
    #expect(snapshot.numberOfSections == 3)
    #expect(snapshot.sectionIdentifiers == ["A", "B", "C"])
  }

  @Test
  func appendItems() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    #expect(snapshot.numberOfItems == 3)
    #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 2, 3])
  }

  @Test
  func appendItemsToLastSection() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2])
    #expect(snapshot.itemIdentifiers(inSection: "B") == [1, 2])
  }

  @Test
  func insertSectionsBeforeAndAfter() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "C"])
    snapshot.insertSections(["B"], beforeSection: "C")
    #expect(snapshot.sectionIdentifiers == ["A", "B", "C"])
    snapshot.insertSections(["D"], afterSection: "C")
    #expect(snapshot.sectionIdentifiers == ["A", "B", "C", "D"])
  }

  @Test
  func insertItemsBeforeAndAfter() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 3], toSection: "A")
    snapshot.insertItems([2], beforeItem: 3)
    #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 2, 3])
    snapshot.insertItems([4], afterItem: 3)
    #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 2, 3, 4])
  }

  @Test
  func deleteSections() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B", "C"])
    snapshot.appendItems([1, 2], toSection: "B")
    snapshot.deleteSections(["B"])
    #expect(snapshot.numberOfSections == 2)
    #expect(snapshot.sectionIdentifiers == ["A", "C"])
    #expect(snapshot.sectionIdentifier(containingItem: 1) == nil)
  }

  @Test
  func deleteItems() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    snapshot.deleteItems([2])
    #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 3])
    #expect(snapshot.numberOfItems == 2)
  }

  @Test
  func deleteAllItems() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2], toSection: "A")
    snapshot.appendItems([3, 4], toSection: "B")
    snapshot.deleteAllItems()
    #expect(snapshot.numberOfItems == 0)
    #expect(snapshot.numberOfSections == 2)
  }

  @Test
  func moveSection() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B", "C"])
    snapshot.moveSection("C", beforeSection: "A")
    #expect(snapshot.sectionIdentifiers == ["C", "A", "B"])
  }

  @Test
  func moveSectionAfter() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B", "C"])
    snapshot.moveSection("A", afterSection: "C")
    #expect(snapshot.sectionIdentifiers == ["B", "C", "A"])
  }

  @Test
  func moveItem() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    snapshot.moveItem(3, beforeItem: 1)
    #expect(snapshot.itemIdentifiers(inSection: "A") == [3, 1, 2])
  }

  @Test
  func moveItemCrossSection() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2], toSection: "A")
    snapshot.appendItems([3], toSection: "B")
    snapshot.moveItem(2, afterItem: 3)
    #expect(snapshot.itemIdentifiers(inSection: "A") == [1])
    #expect(snapshot.itemIdentifiers(inSection: "B") == [3, 2])
    #expect(snapshot.sectionIdentifier(containingItem: 2) == "B")
  }

  @Test
  func sectionContainingItem() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1], toSection: "A")
    snapshot.appendItems([2], toSection: "B")
    #expect(snapshot.sectionIdentifier(containingItem: 1) == "A")
    #expect(snapshot.sectionIdentifier(containingItem: 2) == "B")
    #expect(snapshot.sectionIdentifier(containingItem: 3) == nil)
  }

  @Test
  func indexOfItemAndSection() {
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

  @Test
  func reloadAndReconfigure() {
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

  @Test
  func numberOfItemsInSection() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    snapshot.appendItems([4], toSection: "B")
    #expect(snapshot.numberOfItems(inSection: "A") == 3)
    #expect(snapshot.numberOfItems(inSection: "B") == 1)
  }

  @Test
  func sendableConformance() {
    let snapshot = DiffableDataSourceSnapshot<String, Int>()
    let _: any Sendable = snapshot
  }

  @Test
  func itemIdentifierFastPath() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    snapshot.appendItems([4, 5], toSection: "B")

    // Direct index access — no section ID lookup
    #expect(snapshot.itemIdentifier(inSectionAt: 0, itemIndex: 0) == 1)
    #expect(snapshot.itemIdentifier(inSectionAt: 0, itemIndex: 2) == 3)
    #expect(snapshot.itemIdentifier(inSectionAt: 1, itemIndex: 1) == 5)

    // Bounds checks
    #expect(snapshot.itemIdentifier(inSectionAt: 2, itemIndex: 0) == nil)
    #expect(snapshot.itemIdentifier(inSectionAt: 0, itemIndex: 5) == nil)

    // numberOfItems fast path
    #expect(snapshot.numberOfItems(inSectionAt: 0) == 3)
    #expect(snapshot.numberOfItems(inSectionAt: 1) == 2)
    #expect(snapshot.numberOfItems(inSectionAt: 99) == 0)
  }

  @Test
  func deleteItemsEarlyExit() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B", "C"])
    snapshot.appendItems([1, 2], toSection: "A")
    snapshot.appendItems([3, 4], toSection: "B")
    snapshot.appendItems([5, 6], toSection: "C")

    // Delete item from first section — should stop scanning early
    snapshot.deleteItems([1])
    #expect(snapshot.numberOfItems == 5)
    #expect(snapshot.itemIdentifiers(inSection: "A") == [2])
  }

  @Test
  func isEmptyProperty() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    #expect(snapshot.isEmpty)

    snapshot.appendSections(["A"])
    #expect(!snapshot.isEmpty)

    snapshot.appendItems([1], toSection: "A")
    #expect(!snapshot.isEmpty)

    snapshot.deleteAllItems()
    #expect(!snapshot.isEmpty) // sections still present

    snapshot.deleteSections(["A"])
    #expect(snapshot.isEmpty)
  }

  @Test
  func deleteItemsWithReverseMap() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B", "C"])
    snapshot.appendItems([1, 2], toSection: "A")
    snapshot.appendItems([3, 4], toSection: "B")
    snapshot.appendItems([5, 6], toSection: "C")

    // Trigger reverse map build via insertItems (uses ensureItemToSection)
    snapshot.insertItems([7], afterItem: 6)
    #expect(snapshot.numberOfItems == 7)

    // Now deleteItems should use the reverse map fast path
    snapshot.deleteItems([3, 7])
    #expect(snapshot.numberOfItems == 5)
    #expect(snapshot.itemIdentifiers(inSection: "B") == [4])
    #expect(snapshot.itemIdentifiers(inSection: "C") == [5, 6])
  }

  @Test
  func deleteSectionsDeduplication() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2], toSection: "A")
    snapshot.appendItems([3], toSection: "B")

    // Passing duplicate section IDs should not corrupt numberOfItems
    snapshot.deleteSections(["A", "A"])
    #expect(snapshot.numberOfSections == 1)
    #expect(snapshot.numberOfItems == 1)
  }

  @Test
  func snapshotEquality() {
    var a = DiffableDataSourceSnapshot<String, Int>()
    a.appendSections(["A", "B"])
    a.appendItems([1, 2], toSection: "A")
    a.appendItems([3], toSection: "B")

    var b = DiffableDataSourceSnapshot<String, Int>()
    b.appendSections(["A", "B"])
    b.appendItems([1, 2], toSection: "A")
    b.appendItems([3], toSection: "B")

    #expect(a == b)
  }

  @Test
  func snapshotInequalityDifferentItems() {
    var a = DiffableDataSourceSnapshot<String, Int>()
    a.appendSections(["A"])
    a.appendItems([1, 2], toSection: "A")

    var b = DiffableDataSourceSnapshot<String, Int>()
    b.appendSections(["A"])
    b.appendItems([1, 3], toSection: "A")

    #expect(a != b)
  }

  @Test
  func snapshotInequalityDifferentSections() {
    var a = DiffableDataSourceSnapshot<String, Int>()
    a.appendSections(["A"])
    a.appendItems([1], toSection: "A")

    var b = DiffableDataSourceSnapshot<String, Int>()
    b.appendSections(["B"])
    b.appendItems([1], toSection: "B")

    #expect(a != b)
  }

  @Test
  func snapshotInequalityDifferentSectionOrder() {
    var a = DiffableDataSourceSnapshot<String, Int>()
    a.appendSections(["A", "B"])

    var b = DiffableDataSourceSnapshot<String, Int>()
    b.appendSections(["B", "A"])

    #expect(a != b)
  }

  @Test
  func snapshotEqualityIgnoresReloadMarkers() {
    var a = DiffableDataSourceSnapshot<String, Int>()
    a.appendSections(["A"])
    a.appendItems([1, 2], toSection: "A")

    var b = a
    b.reloadItems([1])
    b.reloadSections(["A"])

    // Reload markers are transient — structural equality should still hold
    #expect(a == b)
  }

  @Test
  func emptySnapshotEquality() {
    let a = DiffableDataSourceSnapshot<String, Int>()
    let b = DiffableDataSourceSnapshot<String, Int>()
    #expect(a == b)
  }

  @Test
  func convenienceInitFromSections() {
    let snapshot = DiffableDataSourceSnapshot(sections: [
      ("A", [1, 2]),
      ("B", [3]),
    ])
    #expect(snapshot.numberOfSections == 2)
    #expect(snapshot.sectionIdentifiers == ["A", "B"])
    #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 2])
    #expect(snapshot.itemIdentifiers(inSection: "B") == [3])
    #expect(snapshot.numberOfItems == 3)
  }

  @Test
  func convenienceInitEmpty() {
    let snapshot = DiffableDataSourceSnapshot<String, Int>(sections: [])
    #expect(snapshot.isEmpty)
  }

  @Test
  func convenienceInitMatchesManualBuild() {
    var manual = DiffableDataSourceSnapshot<String, Int>()
    manual.appendSections(["X", "Y"])
    manual.appendItems([10, 20], toSection: "X")
    manual.appendItems([30, 40, 50], toSection: "Y")

    let convenience = DiffableDataSourceSnapshot(sections: [
      ("X", [10, 20]),
      ("Y", [30, 40, 50]),
    ])

    #expect(manual == convenience)
  }

  @Test
  func sectionIdentifierAtIndex() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B", "C"])

    #expect(snapshot.sectionIdentifier(at: 0) == "A")
    #expect(snapshot.sectionIdentifier(at: 1) == "B")
    #expect(snapshot.sectionIdentifier(at: 2) == "C")
    #expect(snapshot.sectionIdentifier(at: 3) == nil)
    #expect(snapshot.sectionIdentifier(at: -1) == nil)
  }

  @Test
  func replaceItemsInSection() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    snapshot.appendItems([4, 5], toSection: "B")

    snapshot.replaceItems(in: "A", with: [10, 20])
    #expect(snapshot.itemIdentifiers(inSection: "A") == [10, 20])
    #expect(snapshot.itemIdentifiers(inSection: "B") == [4, 5])
    #expect(snapshot.numberOfItems == 4)
  }

  @Test
  func replaceItemsClearsReloadMarkers() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2], toSection: "A")
    snapshot.reloadItems([1])
    snapshot.reconfigureItems([2])

    snapshot.replaceItems(in: "A", with: [3])
    #expect(snapshot.reloadedItemIdentifiers.isEmpty)
    #expect(snapshot.reconfiguredItemIdentifiers.isEmpty)
  }

  @Test
  func removeItemsRemovesMatching() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A", "B"])
    snapshot.appendItems([1, 2, 3], toSection: "A")
    snapshot.appendItems([4, 5, 6], toSection: "B")

    snapshot.removeItems { $0.isMultiple(of: 2) }
    #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 3])
    #expect(snapshot.itemIdentifiers(inSection: "B") == [5])
    #expect(snapshot.numberOfItems == 3)
  }

  @Test
  func removeItemsNoMatch() {
    var snapshot = DiffableDataSourceSnapshot<String, Int>()
    snapshot.appendSections(["A"])
    snapshot.appendItems([1, 2, 3], toSection: "A")

    snapshot.removeItems { _ in false }
    #expect(snapshot.numberOfItems == 3)
    #expect(snapshot.itemIdentifiers(inSection: "A") == [1, 2, 3])
  }
}
