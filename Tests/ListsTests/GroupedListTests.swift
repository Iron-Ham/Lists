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
}
