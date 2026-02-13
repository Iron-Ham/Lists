@testable import ListKit
@testable import Lists
import Testing
import UIKit

struct SnapshotBuilderTests {
    @Test func buildSingleSection() {
        let a = NumberItem(value: 1)
        let b = NumberItem(value: 2)

        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("main") {
                a
                b
            }
        }

        #expect(snapshot.sectionIdentifiers == ["main"])
        #expect(snapshot.itemIdentifiers(inSection: "main") == [a, b])
    }

    @Test func buildMultipleSections() {
        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("first") {
                NumberItem(value: 1)
            }
            SnapshotSection("second") {
                NumberItem(value: 2)
                NumberItem(value: 3)
            }
        }

        #expect(snapshot.numberOfSections == 2)
        #expect(snapshot.numberOfItems(inSection: "first") == 1)
        #expect(snapshot.numberOfItems(inSection: "second") == 2)
    }

    @Test func conditionalSection() {
        let showExtra = true

        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("always") {
                NumberItem(value: 1)
            }
            if showExtra {
                SnapshotSection("extra") {
                    NumberItem(value: 2)
                }
            }
        }

        #expect(snapshot.numberOfSections == 2)
    }

    @Test func conditionalSectionOmitted() {
        let showExtra = false

        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("always") {
                NumberItem(value: 1)
            }
            if showExtra {
                SnapshotSection("extra") {
                    NumberItem(value: 2)
                }
            }
        }

        #expect(snapshot.numberOfSections == 1)
    }

    @Test func conditionalItems() {
        let showThird = true

        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("main") {
                NumberItem(value: 1)
                NumberItem(value: 2)
                if showThird {
                    NumberItem(value: 3)
                }
            }
        }

        #expect(snapshot.numberOfItems == 3)
    }

    @Test func loopSections() {
        let groups = ["A", "B", "C"]

        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            for (index, group) in groups.enumerated() {
                SnapshotSection(group) {
                    NumberItem(value: index)
                }
            }
        }

        #expect(snapshot.numberOfSections == 3)
        #expect(snapshot.sectionIdentifiers == ["A", "B", "C"])
    }

    @Test func arrayPassthroughInItems() {
        let items = [NumberItem(value: 10), NumberItem(value: 20)]

        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("main") {
                items
            }
        }

        #expect(snapshot.itemIdentifiers == items)
    }

    @Test func emptyBuilder() {
        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {}

        #expect(snapshot.numberOfSections == 0)
        #expect(snapshot.numberOfItems == 0)
    }

    @Test func sectionInitWithItemsArray() {
        let items = [NumberItem(value: 1), NumberItem(value: 2)]
        let section = SnapshotSection("test", items: items)

        #expect(section.id == "test")
        #expect(section.items == items)
    }

    @Test func ifElseSections() {
        let useGroupA = false

        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            if useGroupA {
                SnapshotSection("A") {
                    NumberItem(value: 1)
                }
            } else {
                SnapshotSection("B") {
                    NumberItem(value: 2)
                }
            }
        }

        #expect(snapshot.sectionIdentifiers == ["B"])
    }

    @Test func ifElseItems() {
        let useLarge = true

        let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("main") {
                if useLarge {
                    NumberItem(value: 100)
                } else {
                    NumberItem(value: 1)
                }
            }
        }

        #expect(snapshot.itemIdentifiers == [NumberItem(value: 100)])
    }
}
