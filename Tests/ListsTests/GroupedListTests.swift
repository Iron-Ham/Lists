// ABOUTME: Tests for GroupedList: sections with headers/footers, SectionModel, and callbacks.
// ABOUTME: Covers setSections, selection, deletion, move handlers, and query APIs.
import Testing
import UIKit
@testable import ListKit
@testable import Lists

@MainActor
struct GroupedListTests {
  @Test
  func multipleSectionsWithItems() async {
    let list = GroupedList<String, TextItem>()
    let sections = [
      SectionModel(id: "general", items: [TextItem(text: "A")], header: "General"),
      SectionModel(id: "advanced", items: [TextItem(text: "B"), TextItem(text: "C")], header: "Advanced"),
    ]

    await list.setSections(sections, animatingDifferences: false)

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfSections == 2)
    #expect(snapshot.numberOfItems(inSection: "general") == 1)
    #expect(snapshot.numberOfItems(inSection: "advanced") == 2)
  }

  @Test
  func emptySectionsHandled() async {
    let list = GroupedList<String, TextItem>()
    let sections: [SectionModel<String, TextItem>] = [
      SectionModel(id: "empty", items: [], header: "Empty Section")
    ]

    await list.setSections(sections, animatingDifferences: false)

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfSections == 1)
    #expect(snapshot.numberOfItems(inSection: "empty") == 0)
  }

  @Test
  func sectionWithHeaderAndFooter() async {
    let list = GroupedList<String, TextItem>()
    let sections = [
      SectionModel(
        id: "info",
        items: [TextItem(text: "Item")],
        header: "Header Text",
        footer: "Footer Text"
      )
    ]

    await list.setSections(sections, animatingDifferences: false)

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfSections == 1)
    #expect(snapshot.numberOfItems == 1)
  }

  @Test
  func replaceSectionsUpdatesSnapshot() async {
    let list = GroupedList<String, TextItem>()

    await list.setSections([
      SectionModel(id: "A", items: [TextItem(text: "1")])
    ], animatingDifferences: false)

    #expect(list.snapshot().numberOfSections == 1)

    await list.setSections([
      SectionModel(id: "X", items: [TextItem(text: "a")]),
      SectionModel(id: "Y", items: [TextItem(text: "b")]),
    ], animatingDifferences: false)

    #expect(list.snapshot().numberOfSections == 2)
  }

  @Test
  func rapidSectionReplacementProducesCorrectFinalState() async {
    let list = GroupedList<String, TextItem>()

    async let _ = list.setSections([
      SectionModel(id: "A", items: [TextItem(text: "1")])
    ], animatingDifferences: false)

    async let _ = list.setSections([
      SectionModel(id: "B", items: [TextItem(text: "2")])
    ], animatingDifferences: false)

    await list.setSections([
      SectionModel(id: "X", items: [TextItem(text: "final")], header: "Final Header")
    ], animatingDifferences: false)

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfSections == 1)
    #expect(snapshot.sectionIdentifiers == ["X"])
    #expect(snapshot.numberOfItems == 1)
  }

  @Test
  func clearAllSections() async {
    let list = GroupedList<String, TextItem>()

    await list.setSections([
      SectionModel(id: "A", items: [TextItem(text: "1")], header: "H")
    ], animatingDifferences: false)
    #expect(list.snapshot().numberOfSections == 1)

    await list.setSections([], animatingDifferences: false)
    #expect(list.snapshot().numberOfSections == 0)
    #expect(list.snapshot().numberOfItems == 0)
  }

  @Test
  func sectionModelAcceptsNonCellViewModelItems() {
    // SectionModel should accept any Hashable & Sendable type, not just CellViewModel.
    // This enables the inline-content convenience initializers on GroupedListView.
    let section = SectionModel(id: "test", items: ["Hello", "World"], header: "Strings")
    #expect(section.id == "test")
    #expect(section.items == ["Hello", "World"])
    #expect(section.header == "Strings")

    let intSection = SectionModel(id: 0, items: [1, 2, 3])
    #expect(intSection.items.count == 3)
  }

  @Test
  func onDeleteCallbackIsStored() {
    let list = GroupedList<String, TextItem>()
    var deletedItem: TextItem?
    list.onDelete = { item in deletedItem = item }
    list.onDelete?(TextItem(text: "Z"))
    #expect(deletedItem?.text == "Z")
  }

  @Test
  func onMoveCallbackIsWired() {
    let list = GroupedList<String, TextItem>()

    var movedSource: IndexPath?
    var movedDest: IndexPath?
    list.onMove = { source, dest in
      movedSource = source
      movedDest = dest
    }

    #expect(list.collectionView.dragInteractionEnabled == true)

    list.onMove?(IndexPath(item: 0, section: 0), IndexPath(item: 1, section: 0))
    #expect(movedSource == IndexPath(item: 0, section: 0))
    #expect(movedDest == IndexPath(item: 1, section: 0))
  }

  @Test
  func clearingOnMoveDisablesDragInteraction() {
    let list = GroupedList<String, TextItem>()
    list.onMove = { _, _ in }
    #expect(list.collectionView.dragInteractionEnabled == true)

    list.onMove = nil
    #expect(list.collectionView.dragInteractionEnabled == false)
  }

  @Test
  func sectionIdentifierForIndex() async {
    let list = GroupedList<String, TextItem>()
    await list.setSections([
      SectionModel(id: "alpha", items: [TextItem(text: "A")]),
      SectionModel(id: "beta", items: [TextItem(text: "B")]),
    ], animatingDifferences: false)

    #expect(list.sectionIdentifier(for: 0) == "alpha")
    #expect(list.sectionIdentifier(for: 1) == "beta")
    #expect(list.sectionIdentifier(for: 99) == nil)
  }

  @Test
  func indexForSectionIdentifier() async {
    let list = GroupedList<String, TextItem>()
    await list.setSections([
      SectionModel(id: "alpha", items: [TextItem(text: "A")]),
      SectionModel(id: "beta", items: [TextItem(text: "B")]),
    ], animatingDifferences: false)

    #expect(list.index(for: "alpha") == 0)
    #expect(list.index(for: "beta") == 1)
    #expect(list.index(for: "nonexistent") == nil)
  }

  @Test
  func sectionQueryOnEmptyList() {
    let list = GroupedList<String, TextItem>()
    #expect(list.sectionIdentifier(for: 0) == nil)
    #expect(list.index(for: "any") == nil)
  }

  @Test
  func itemsInSection() async {
    let a = TextItem(text: "A")
    let b = TextItem(text: "B")
    let c = TextItem(text: "C")

    let list = GroupedList<String, TextItem>()
    await list.setSections([
      SectionModel(id: "first", items: [a, b]),
      SectionModel(id: "second", items: [c]),
    ], animatingDifferences: false)

    let firstItems = list.items(in: "first")
    #expect(firstItems?.count == 2)
    #expect(firstItems?[0] == a)

    let secondItems = list.items(in: "second")
    #expect(secondItems?.count == 1)

    #expect(list.items(in: "missing") == nil)
  }

  @Test
  func itemsInEmptySection() async {
    let list = GroupedList<String, TextItem>()
    await list.setSections([
      SectionModel(id: "empty", items: [], header: "Empty")
    ], animatingDifferences: false)

    let items = list.items(in: "empty")
    #expect(items != nil)
    #expect(items?.isEmpty == true)
  }

  @Test
  func numberOfItemsAndSections() async {
    let list = GroupedList<String, TextItem>()
    await list.setSections([
      SectionModel(id: "a", items: [TextItem(text: "1"), TextItem(text: "2")]),
      SectionModel(id: "b", items: [TextItem(text: "3")]),
    ], animatingDifferences: false)

    #expect(list.numberOfItems == 3)
    #expect(list.numberOfSections == 2)
  }

  @Test
  func selectedItemsDefaultsToEmpty() {
    let list = GroupedList<String, TextItem>()
    #expect(list.selectedItems.isEmpty)
  }

  @Test
  func deselectAllClearsSelection() async {
    let list = GroupedList<String, TextItem>()
    list.allowsMultipleSelection = true
    await list.setSections([
      SectionModel(id: "A", items: [TextItem(text: "1"), TextItem(text: "2")])
    ], animatingDifferences: false)

    list.collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: [])
    list.collectionView.selectItem(at: IndexPath(item: 1, section: 0), animated: false, scrollPosition: [])
    #expect((list.collectionView.indexPathsForSelectedItems ?? []).count == 2)

    list.deselectAll(animated: false)
    #expect((list.collectionView.indexPathsForSelectedItems ?? []).isEmpty)
  }

  @Test
  func sectionModelIsIdentifiable() {
    let section = SectionModel(id: "test", items: [TextItem(text: "A")])
    #expect(section.id == "test")
    let _: any Identifiable = section
  }

  @Test
  func sectionModelMapItemsTransformsItems() {
    let section = SectionModel(id: "test", items: [1, 2, 3], header: "H", footer: "F")
    let mapped = section.mapItems { String($0) }

    #expect(mapped.id == "test")
    #expect(mapped.items == ["1", "2", "3"])
    #expect(mapped.header == "H")
    #expect(mapped.footer == "F")
  }

  @Test
  func sectionModelMapItemsPreservesNilHeaderFooter() {
    let section = SectionModel(id: "test", items: [42])
    let mapped = section.mapItems { $0 * 2 }

    #expect(mapped.items == [84])
    #expect(mapped.header == nil)
    #expect(mapped.footer == nil)
  }
}
