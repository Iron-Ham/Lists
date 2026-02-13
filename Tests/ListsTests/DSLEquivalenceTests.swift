import Foundation
@testable import ListKit
@testable import Lists
import Testing

struct DSLEquivalenceTests {
    // MARK: - Snapshot Equivalence

    @Test func dslProducesSameSnapshotAsManual() {
        let a = NumberItem(value: 1)
        let b = NumberItem(value: 2)
        let c = NumberItem(value: 3)

        // Manual
        var manual = DiffableDataSourceSnapshot<String, NumberItem>()
        manual.appendSections(["first", "second"])
        manual.appendItems([a, b], toSection: "first")
        manual.appendItems([c], toSection: "second")

        // DSL
        let dsl = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("first") {
                a
                b
            }
            SnapshotSection("second") {
                c
            }
        }

        #expect(manual.sectionIdentifiers == dsl.sectionIdentifiers)
        #expect(manual.itemIdentifiers == dsl.itemIdentifiers)
        for section in manual.sectionIdentifiers {
            #expect(manual.itemIdentifiers(inSection: section) == dsl.itemIdentifiers(inSection: section))
        }
    }

    @Test func dslWithConditionalsProducesCorrectSnapshot() {
        let showExtra = true

        // Manual
        var manual = DiffableDataSourceSnapshot<String, NumberItem>()
        manual.appendSections(["main"])
        var items = [NumberItem(value: 1), NumberItem(value: 2)]
        if showExtra {
            items.append(NumberItem(value: 3))
        }
        manual.appendItems(items, toSection: "main")

        // DSL
        let dsl = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("main") {
                NumberItem(value: 1)
                NumberItem(value: 2)
                if showExtra {
                    NumberItem(value: 3)
                }
            }
        }

        #expect(manual.itemIdentifiers == dsl.itemIdentifiers)
    }

    @Test func dslWithLoopsProducesCorrectSnapshot() {
        let groups = ["A", "B", "C"]
        let itemsPerGroup = 5

        // Manual
        var manual = DiffableDataSourceSnapshot<String, NumberItem>()
        for (index, group) in groups.enumerated() {
            manual.appendSections([group])
            let items = (0 ..< itemsPerGroup).map { NumberItem(value: index * 100 + $0) }
            manual.appendItems(items, toSection: group)
        }

        // DSL
        let dsl = DiffableDataSourceSnapshot<String, NumberItem> {
            for (index, group) in groups.enumerated() {
                SnapshotSection(group) {
                    (0 ..< itemsPerGroup).map { NumberItem(value: index * 100 + $0) }
                }
            }
        }

        #expect(manual.sectionIdentifiers == dsl.sectionIdentifiers)
        #expect(manual.itemIdentifiers == dsl.itemIdentifiers)
    }

    // MARK: - Diff Equivalence

    @Test func diffFromDSLSnapshotsMatchesDiffFromManualSnapshots() {
        // Build "old" state both ways
        var oldManual = DiffableDataSourceSnapshot<String, NumberItem>()
        oldManual.appendSections(["A", "B"])
        oldManual.appendItems([NumberItem(value: 1), NumberItem(value: 2)], toSection: "A")
        oldManual.appendItems([NumberItem(value: 3)], toSection: "B")

        let oldDSL = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("A") {
                NumberItem(value: 1)
                NumberItem(value: 2)
            }
            SnapshotSection("B") {
                NumberItem(value: 3)
            }
        }

        // Build "new" state both ways
        var newManual = DiffableDataSourceSnapshot<String, NumberItem>()
        newManual.appendSections(["A", "B", "C"])
        newManual.appendItems([NumberItem(value: 2)], toSection: "A")
        newManual.appendItems([NumberItem(value: 3), NumberItem(value: 4)], toSection: "B")
        newManual.appendItems([NumberItem(value: 5)], toSection: "C")

        let newDSL = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("A") {
                NumberItem(value: 2)
            }
            SnapshotSection("B") {
                NumberItem(value: 3)
                NumberItem(value: 4)
            }
            SnapshotSection("C") {
                NumberItem(value: 5)
            }
        }

        let manualDiff = SectionedDiff.diff(old: oldManual, new: newManual)
        let dslDiff = SectionedDiff.diff(old: oldDSL, new: newDSL)

        // Both diffs should produce identical changesets
        #expect(manualDiff.sectionDeletes == dslDiff.sectionDeletes)
        #expect(manualDiff.sectionInserts == dslDiff.sectionInserts)
        #expect(manualDiff.sectionMoves.count == dslDiff.sectionMoves.count)
        #expect(manualDiff.itemDeletes == dslDiff.itemDeletes)
        #expect(manualDiff.itemInserts == dslDiff.itemInserts)
        #expect(manualDiff.itemMoves.count == dslDiff.itemMoves.count)
    }

    @Test func dslSnapshotDiffProducesCorrectChangeset() {
        let old = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("main") {
                NumberItem(value: 1)
                NumberItem(value: 2)
                NumberItem(value: 3)
            }
        }

        let new = DiffableDataSourceSnapshot<String, NumberItem> {
            SnapshotSection("main") {
                NumberItem(value: 2)
                NumberItem(value: 3)
                NumberItem(value: 4)
            }
        }

        let changeset = SectionedDiff.diff(old: old, new: new)

        // Item 1 deleted, item 4 inserted
        #expect(changeset.itemDeletes.count == 1)
        #expect(changeset.itemInserts.count == 1)
        #expect(changeset.sectionDeletes.isEmpty)
        #expect(changeset.sectionInserts.isEmpty)
    }

    // MARK: - Identifiable Convenience

    @Test func identifiableViewModelHashesByID() {
        let a = IdentifiableItem(id: "abc", title: "Hello")
        let b = IdentifiableItem(id: "abc", title: "World") // same id, different title
        let c = IdentifiableItem(id: "xyz", title: "Hello") // different id, same title

        #expect(a == b, "Same id should be equal")
        #expect(a != c, "Different id should not be equal")
        #expect(a.hashValue == b.hashValue, "Same id should have same hash")
    }

    @Test func identifiableViewModelWorksInSnapshot() {
        let items = [
            IdentifiableItem(id: "1", title: "First"),
            IdentifiableItem(id: "2", title: "Second"),
        ]

        let snapshot = DiffableDataSourceSnapshot<String, IdentifiableItem> {
            SnapshotSection("main") {
                items
            }
        }

        #expect(snapshot.numberOfItems == 2)

        // Update title but keep same id — should be detected as same item
        let updated = IdentifiableItem(id: "1", title: "Updated First")
        #expect(items[0] == updated)
    }
}

// Test fixture using the Identifiable convenience
import UIKit

struct IdentifiableItem: CellViewModel, Identifiable {
    typealias Cell = UICollectionViewListCell
    let id: String
    let title: String

    // No == or hash(into:) needed — provided by CellViewModel+Identifiable extension

    @MainActor func configure(_ cell: UICollectionViewListCell) {
        var content = cell.defaultContentConfiguration()
        content.text = title
        cell.contentConfiguration = content
    }
}
