// ABOUTME: Tests for SectionedDiff: section and item inserts, deletes, moves, and reloads.
// ABOUTME: Validates cross-section moves, reload markers, and changeset properties.
import Foundation
import Testing
@testable import ListKit

struct SectionedDiffTests {
  @Test
  func addSection() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1, 2], toSection: "A")
    new.appendItems([3], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.sectionInserts == IndexSet([1]))
    #expect(changeset.sectionDeletes.isEmpty)
  }

  @Test
  func removeSection() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1], toSection: "A")
    old.appendItems([2], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.sectionDeletes == IndexSet([1]))
    #expect(changeset.sectionInserts.isEmpty)
  }

  @Test
  func moveSection() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B", "C"])

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["C", "A", "B"])

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(!changeset.sectionMoves.isEmpty)
  }

  @Test
  func addItemWithinSection() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.sectionDeletes.isEmpty)
    #expect(changeset.sectionInserts.isEmpty)
    #expect(changeset.itemInserts.contains(IndexPath(item: 2, section: 0)))
  }

  @Test
  func removeItemWithinSection() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 3], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.itemDeletes.contains(IndexPath(item: 1, section: 0)))
  }

  @Test
  func moveItemWithinSection() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([3, 1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(!changeset.itemMoves.isEmpty)
  }

  @Test
  func crossSectionItemMove() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1], toSection: "A")
    new.appendItems([3, 2], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)
    // Item 2 moved from section A to section B
    let hasCrossSectionMove = changeset.itemMoves.contains { move in
      move.from.section != move.to.section
    }
    #expect(hasCrossSectionMove)
  }

  @Test
  func combinedSectionAndItemChanges() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3, 4], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B", "C"])
    new.appendItems([3, 5], toSection: "B")
    new.appendItems([6], toSection: "C")

    let changeset = SectionedDiff.diff(old: old, new: new)
    // Section A deleted, Section C inserted
    #expect(changeset.sectionDeletes.contains(0))
    #expect(!changeset.sectionInserts.isEmpty)
  }

  @Test
  func reloadsAndReconfigures() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")
    new.reloadItems([1])
    new.reconfigureItems([2])

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.itemReloads.contains(IndexPath(item: 0, section: 0)))
    #expect(changeset.itemReconfigures.contains(IndexPath(item: 1, section: 0)))
  }

  @Test
  func sectionReloads() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3, 4], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1, 2], toSection: "A")
    new.appendItems([3, 4], toSection: "B")
    new.reloadSections(["B"])

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.sectionReloads == IndexSet([1]))
    // No structural changes — only the section reload
    #expect(changeset.sectionDeletes.isEmpty)
    #expect(changeset.sectionInserts.isEmpty)
    #expect(changeset.itemDeletes.isEmpty)
    #expect(changeset.itemInserts.isEmpty)
  }

  @Test
  func sectionReloadIgnoredForDeletedSection() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1], toSection: "A")
    old.appendItems([2], toSection: "B")

    // Section A is removed from new, but also marked for reload
    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B"])
    new.appendItems([2], toSection: "B")
    new.reloadSections(["A"])

    let changeset = SectionedDiff.diff(old: old, new: new)
    // Section A was deleted — reload should be ignored
    #expect(changeset.sectionReloads.isEmpty)
    #expect(changeset.sectionDeletes == IndexSet([0]))
  }

  @Test
  func sectionReloadIgnoredForInsertedSection() {
    let old = DiffableDataSourceSnapshot<String, Int>()

    // Section A is new (not in old) but marked for reload
    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1], toSection: "A")
    new.reloadSections(["A"])

    let changeset = SectionedDiff.diff(old: old, new: new)
    // Section A is inserted — reload should be ignored since it's new
    #expect(changeset.sectionReloads.isEmpty)
    #expect(changeset.sectionInserts == IndexSet([0]))
  }

  @Test
  func sectionReloadUsesNewIndex() {
    // Section B moves from index 1 to index 0 and is reloaded
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1], toSection: "A")
    old.appendItems([2], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B", "A"])
    new.appendItems([2], toSection: "B")
    new.appendItems([1], toSection: "A")
    new.reloadSections(["B"])

    let changeset = SectionedDiff.diff(old: old, new: new)
    // Should use B's NEW index (0), not its old index (1)
    #expect(changeset.sectionReloads == IndexSet([0]))
  }

  @Test
  func sectionReloadMakesChangesetNonEmpty() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1], toSection: "A")
    new.reloadSections(["A"])

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(!changeset.isEmpty)
    #expect(changeset.sectionReloads == IndexSet([0]))
  }

  @Test
  func bothEmpty() {
    let old = DiffableDataSourceSnapshot<String, Int>()
    let new = DiffableDataSourceSnapshot<String, Int>()

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.isEmpty)
  }

  @Test
  func emptyToPopulated() {
    let old = DiffableDataSourceSnapshot<String, Int>()

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.sectionInserts == IndexSet([0]))
  }

  @Test
  func populatedToEmpty() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    let new = DiffableDataSourceSnapshot<String, Int>()

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.sectionDeletes == IndexSet([0]))
  }

  @Test
  func noChange() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.sectionDeletes.isEmpty)
    #expect(changeset.sectionInserts.isEmpty)
    #expect(changeset.sectionMoves.isEmpty)
    #expect(changeset.sectionReloads.isEmpty)
    #expect(changeset.itemDeletes.isEmpty)
    #expect(changeset.itemInserts.isEmpty)
    #expect(changeset.itemMoves.isEmpty)
  }

  @Test
  func changesetIsEmpty() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.isEmpty)
  }

  @Test
  func itemSurvivesDeletedSection() {
    // Item 1 is in section A (deleted), but reappears in section B (survives)
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B"])
    new.appendItems([1, 3], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)
    // Section A is deleted (handles removal of item 2)
    #expect(changeset.sectionDeletes == IndexSet([0]))
    // Item 1 must be explicitly inserted into section B
    let insertedItem1 = changeset.itemInserts.contains(IndexPath(item: 0, section: 0))
    #expect(insertedItem1)
  }

  @Test
  func itemMovesToInsertedSection() {
    // Item 2 moves from section A (survives) to section C (inserted)
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "C"])
    new.appendItems([1], toSection: "A")
    new.appendItems([2], toSection: "C")

    let changeset = SectionedDiff.diff(old: old, new: new)
    // Section C is inserted (handles addition of item 2 there)
    #expect(!changeset.sectionInserts.isEmpty)
    // Item 2 must be explicitly deleted from section A
    let deletedItem2 = changeset.itemDeletes.contains(IndexPath(item: 1, section: 0))
    #expect(deletedItem2)
  }

  @Test
  func itemCrossesDeletedAndInsertedSection() {
    // Item moves from a deleted section to an inserted section — both section ops handle it
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B"])
    new.appendItems([1], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new)
    #expect(changeset.sectionDeletes == IndexSet([0]))
    #expect(changeset.sectionInserts == IndexSet([0]))
    // No explicit item operations needed — section ops handle everything
    #expect(changeset.itemDeletes.isEmpty)
    #expect(changeset.itemInserts.isEmpty)
    #expect(changeset.itemMoves.isEmpty)
  }

  @Test
  func changesetHasStructuralChanges() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    // Reconfigure-only: no structural changes
    var reconfigureOnly = DiffableDataSourceSnapshot<String, Int>()
    reconfigureOnly.appendSections(["A"])
    reconfigureOnly.appendItems([1, 2, 3], toSection: "A")
    reconfigureOnly.reconfigureItems([1])

    let reconfigureChangeset = SectionedDiff.diff(old: old, new: reconfigureOnly)
    #expect(!reconfigureChangeset.isEmpty)
    #expect(!reconfigureChangeset.hasStructuralChanges)

    // Structural: item insert
    var withInsert = DiffableDataSourceSnapshot<String, Int>()
    withInsert.appendSections(["A"])
    withInsert.appendItems([1, 2, 3, 4], toSection: "A")

    let insertChangeset = SectionedDiff.diff(old: old, new: withInsert)
    #expect(insertChangeset.hasStructuralChanges)
  }

  @Test
  func changesetEquatable() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")

    let changeset1 = SectionedDiff.diff(old: old, new: new)
    let changeset2 = SectionedDiff.diff(old: old, new: new)
    #expect(changeset1 == changeset2)
  }
}
