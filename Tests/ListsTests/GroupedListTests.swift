@testable import ListKit
@testable import Lists
import Testing
import UIKit

@MainActor
struct GroupedListTests {
    @Test func multipleSectionsWithItems() async {
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

    @Test func emptySectionsHandled() async {
        let list = GroupedList<String, TextItem>()
        let sections: [SectionModel<String, TextItem>] = [
            SectionModel(id: "empty", items: [], header: "Empty Section"),
        ]

        await list.setSections(sections, animatingDifferences: false)

        let snapshot = list.snapshot()
        #expect(snapshot.numberOfSections == 1)
        #expect(snapshot.numberOfItems(inSection: "empty") == 0)
    }

    @Test func sectionWithHeaderAndFooter() async {
        let list = GroupedList<String, TextItem>()
        let sections = [
            SectionModel(
                id: "info",
                items: [TextItem(text: "Item")],
                header: "Header Text",
                footer: "Footer Text"
            ),
        ]

        await list.setSections(sections, animatingDifferences: false)

        let snapshot = list.snapshot()
        #expect(snapshot.numberOfSections == 1)
        #expect(snapshot.numberOfItems == 1)
    }

    @Test func replaceSectionsUpdatesSnapshot() async {
        let list = GroupedList<String, TextItem>()

        await list.setSections([
            SectionModel(id: "A", items: [TextItem(text: "1")]),
        ], animatingDifferences: false)

        #expect(list.snapshot().numberOfSections == 1)

        await list.setSections([
            SectionModel(id: "X", items: [TextItem(text: "a")]),
            SectionModel(id: "Y", items: [TextItem(text: "b")]),
        ], animatingDifferences: false)

        #expect(list.snapshot().numberOfSections == 2)
    }
}
