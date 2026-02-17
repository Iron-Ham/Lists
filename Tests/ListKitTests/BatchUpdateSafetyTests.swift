// ABOUTME: Tests that SectionedDiff produces changesets safe for UICollectionView batch updates.
// ABOUTME: Validates index ordering, deduplication, and section/item operation consistency.
import Foundation
import Testing
@testable import ListKit

/// Validates that SectionedDiff produces changesets that are safe for
/// UICollectionView.performBatchUpdates. Inspired by IGListKit's
/// IGListBatchUpdateDataTests — their most battle-tested area.
///
/// UICollectionView batch update rules:
/// - Deletes use OLD indices, inserts use NEW indices
/// - Moves use (old, new) pairs
/// - Deletes are processed before inserts
/// - An item in a deleted section should NOT also appear in item deletes
/// - An item in an inserted section should NOT also appear in item inserts
/// - Item deletes should be sorted descending, inserts ascending
/// - No duplicate indices in any operation array
struct BatchUpdateSafetyTests {
  /// Item deletes should be sorted descending (end → start) for safe removal.
  @Test
  func itemDeletesSortedDescending() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3, 4, 5], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 5], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)

    // Items 2, 3, 4 deleted — should be in descending order
    let deleteItems = changeset.itemDeletes.map(\.item)
    #expect(deleteItems == deleteItems.sorted(by: >))
  }

  /// Item inserts should be sorted ascending (start → end).
  @Test
  func itemInsertsSortedAscending() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 5], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3, 4, 5], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)

    let insertItems = changeset.itemInserts.map(\.item)
    #expect(insertItems == insertItems.sorted())
  }

  /// No index should appear twice in item deletes.
  @Test
  func noItemDeleteDuplicates() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2, 3], toSection: "A")
    old.appendItems([4, 5, 6], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1], toSection: "A")
    new.appendItems([4], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)

    #expect(
      Set(changeset.itemDeletes).count == changeset.itemDeletes.count,
      "Duplicate item deletes found"
    )
  }

  /// No index should appear twice in item inserts.
  @Test
  func noItemInsertDuplicates() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1], toSection: "A")
    old.appendItems([4], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1, 2, 3], toSection: "A")
    new.appendItems([4, 5, 6], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)

    #expect(
      Set(changeset.itemInserts).count == changeset.itemInserts.count,
      "Duplicate item inserts found"
    )
  }

  /// Items in a deleted section should NOT appear in item deletes.
  /// The section delete handles all items in that section.
  @Test
  func itemsInDeletedSectionNotInItemDeletes() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3, 4], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B"])
    new.appendItems([3, 4], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)

    #expect(changeset.sectionDeletes == IndexSet([0]))
    // No item deletes should reference section 0 — the section delete handles it
    let deletesInDeletedSection = changeset.itemDeletes.filter { $0.section == 0 }
    #expect(
      deletesInDeletedSection.isEmpty,
      "Items in deleted section should not appear in item deletes"
    )
  }

  /// Items in an inserted section should NOT appear in item inserts.
  @Test
  func itemsInInsertedSectionNotInItemInserts() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1], toSection: "A")
    new.appendItems([2, 3], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)

    #expect(changeset.sectionInserts == IndexSet([1]))
    // No item inserts should reference section 1 — the section insert handles it
    let insertsInInsertedSection = changeset.itemInserts.filter { $0.section == 1 }
    #expect(
      insertsInInsertedSection.isEmpty,
      "Items in inserted section should not appear in item inserts"
    )
  }

  /// Items within a moved section should use correct section indices.
  @Test
  func itemChangesInMovedSectionUseCorrectIndices() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3, 4], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B", "A"])
    new.appendItems([3, 4, 5], toSection: "B")
    new.appendItems([1], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)

    // Item 2 deleted from section A (old index 0)
    let deletedItem2 = changeset.itemDeletes.contains { $0.item == 1 && $0.section == 0 }
    #expect(deletedItem2)

    // Item 5 inserted into section B (new index 0)
    let insertedItem5 = changeset.itemInserts.contains { $0.item == 2 && $0.section == 0 }
    #expect(insertedItem5)
  }

  /// A cross-section move should not also appear as a delete + insert pair.
  @Test
  func crossSectionMoveNotDuplicatedAsDeleteInsert() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2, 3], toSection: "A")
    old.appendItems([4, 5], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1, 3], toSection: "A")
    new.appendItems([4, 2, 5], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)

    // Item 2 should be a cross-section move
    let moveOf2 = changeset.itemMoves.first { move in
      move.from.section == 0 && move.from.item == 1
    }
    #expect(moveOf2 != nil)

    // Item 2 should NOT also be in deletes or inserts
    let deleteOf2 = changeset.itemDeletes.contains { $0.section == 0 && $0.item == 1 }
    #expect(!deleteOf2, "Cross-section move should not also be a delete")
  }

  /// The changeset should produce the correct net item count per section.
  /// For surviving sections: old_count + inserts - deletes - moves_out + moves_in = new_count
  @Test
  func netItemCountIsConsistent() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2, 3, 4], toSection: "A")
    old.appendItems([5, 6], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1, 3, 7], toSection: "A")
    new.appendItems([2, 5, 6, 8], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)

    // Verify total items: old had 6, new has 7 → net +1
    let totalInserts = changeset.itemInserts.count
    let totalDeletes = changeset.itemDeletes.count
    // Moves don't change total count
    #expect(6 + totalInserts - totalDeletes == 7)
  }

  /// Deleting multiple sections at once — indices should be from old snapshot.
  @Test
  func multipleSectionDeletesUseOldIndices() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B", "C", "D"])
    old.appendItems([1], toSection: "A")
    old.appendItems([2], toSection: "B")
    old.appendItems([3], toSection: "C")
    old.appendItems([4], toSection: "D")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "D"])
    new.appendItems([1], toSection: "A")
    new.appendItems([4], toSection: "D")

    let changeset = SectionedDiff.diff(old: old, new: new)

    // Sections B (1) and C (2) deleted — using OLD indices
    #expect(changeset.sectionDeletes == IndexSet([1, 2]))
  }

  /// Inserting multiple sections at once — indices should be from new snapshot.
  @Test
  func multipleSectionInsertsUseNewIndices() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B", "A", "C"])
    new.appendItems([2], toSection: "B")
    new.appendItems([1], toSection: "A")
    new.appendItems([3], toSection: "C")

    let changeset = SectionedDiff.diff(old: old, new: new)

    // Sections B (0) and C (2) inserted — using NEW indices
    #expect(changeset.sectionInserts == IndexSet([0, 2]))
  }

  /// Simultaneous section delete, insert, and move with item changes.
  @Test
  func simultaneousSectionDeleteInsertMoveWithItemChanges() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B", "C"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3, 4], toSection: "B")
    old.appendItems([5, 6], toSection: "C")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["C", "D", "B"])
    new.appendItems([5, 7], toSection: "C") // 6 deleted, 7 inserted
    new.appendItems([8], toSection: "D") // new section
    new.appendItems([3], toSection: "B") // 4 deleted

    let changeset = SectionedDiff.diff(old: old, new: new)

    // Section A deleted
    #expect(changeset.sectionDeletes.contains(0))
    // Section D inserted
    #expect(!changeset.sectionInserts.isEmpty)
    // Should not crash UICollectionView
    // Verify no items reference deleted/inserted sections incorrectly
    for delete in changeset.itemDeletes {
      #expect(
        !changeset.sectionDeletes.contains(delete.section),
        "Item delete references a deleted section"
      )
    }
  }

  /// Replacing all sections — complete structural change.
  @Test
  func completeStructuralReplacement() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3, 4], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["C", "D"])
    new.appendItems([5, 6], toSection: "C")
    new.appendItems([7, 8], toSection: "D")

    let changeset = SectionedDiff.diff(old: old, new: new)

    #expect(changeset.sectionDeletes == IndexSet([0, 1]))
    #expect(changeset.sectionInserts == IndexSet([0, 1]))
    // No item-level operations needed — section ops handle everything
    #expect(changeset.itemDeletes.isEmpty)
    #expect(changeset.itemInserts.isEmpty)
  }

  /// Move `from` should reference an old index, `to` should reference a new index.
  @Test
  func sectionMoveIndicesReferenceCorrectSnapshots() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B", "C"])

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["C", "B", "A"])

    let changeset = SectionedDiff.diff(old: old, new: new)

    for move in changeset.sectionMoves {
      #expect(move.from >= 0 && move.from < old.numberOfSections)
      #expect(move.to >= 0 && move.to < new.numberOfSections)
    }
  }

  /// Item move `from` should reference old snapshot, `to` should reference new.
  @Test
  func itemMoveIndicesReferenceCorrectSnapshots() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3, 4, 5], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([5, 4, 3, 2, 1], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)

    for move in changeset.itemMoves {
      #expect(move.from.item >= 0 && move.from.item < 5)
      #expect(move.to.item >= 0 && move.to.item < 5)
    }
  }

  /// Single-section snapshots should produce correct results without
  /// cross-section move reconciliation.
  @Test
  func singleSectionDiffProducesCorrectResults() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3, 4, 5], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([2, 4, 6], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)

    // 1, 3, 5 deleted; 6 inserted; 2, 4 survive
    #expect(changeset.itemDeletes.count == 3)
    #expect(changeset.itemInserts.count == 1)
    #expect(changeset.sectionDeletes.isEmpty)
    #expect(changeset.sectionInserts.isEmpty)
  }

  /// Single-section with moves should work correctly via fast path.
  @Test
  func singleSectionMovesWorkCorrectly() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([3, 1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)

    #expect(changeset.itemDeletes.isEmpty)
    #expect(changeset.itemInserts.isEmpty)
    #expect(!changeset.itemMoves.isEmpty)
  }

  /// Reload items should coexist with structural changes without conflict.
  @Test
  func reloadCoexistsWithStructuralChanges() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3, 4], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 5], toSection: "A") // 3,4 deleted, 5 inserted
    new.reloadItems([1]) // item 1 reloaded

    let changeset = SectionedDiff.diff(old: old, new: new)

    #expect(changeset.hasStructuralChanges)
    #expect(!changeset.itemReloads.isEmpty)
    // Reload should reference new index of item 1
    #expect(changeset.itemReloads.contains(IndexPath(item: 0, section: 0)))
  }

  /// Reconfigure items should coexist with structural changes.
  @Test
  func reconfigureCoexistsWithStructuralChanges() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 3, 4], toSection: "A") // 2 deleted, 4 inserted
    new.reconfigureItems([1])

    let changeset = SectionedDiff.diff(old: old, new: new)

    #expect(changeset.hasStructuralChanges)
    #expect(!changeset.itemReconfigures.isEmpty)
  }
}
