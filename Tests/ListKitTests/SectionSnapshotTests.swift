import Testing
@testable import ListKit

struct SectionSnapshotTests {
  @Test
  func emptySnapshot() {
    let snapshot = DiffableDataSourceSectionSnapshot<String>()
    #expect(snapshot.items.isEmpty)
    #expect(snapshot.rootItems.isEmpty)
    #expect(snapshot.visibleItems.isEmpty)
  }

  @Test
  func appendRootItems() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A", "B", "C"])
    #expect(snapshot.items == ["A", "B", "C"])
    #expect(snapshot.rootItems == ["A", "B", "C"])
  }

  @Test
  func appendChildItems() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A"])
    snapshot.append(["A1", "A2"], to: "A")
    #expect(snapshot.items == ["A", "A1", "A2"])
    #expect(snapshot.rootItems == ["A"])
    #expect(snapshot.parent(of: "A1") == "A")
    #expect(snapshot.parent(of: "A") == nil)
  }

  @Test
  func nestedChildren() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["Root"])
    snapshot.append(["Child"], to: "Root")
    snapshot.append(["Grandchild"], to: "Child")
    #expect(snapshot.level(of: "Root") == 0)
    #expect(snapshot.level(of: "Child") == 1)
    #expect(snapshot.level(of: "Grandchild") == 2)
  }

  @Test
  func expandAndCollapse() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A"])
    snapshot.append(["A1", "A2"], to: "A")
    #expect(snapshot.isExpanded("A") == false)
    snapshot.expand(["A"])
    #expect(snapshot.isExpanded("A") == true)
    snapshot.collapse(["A"])
    #expect(snapshot.isExpanded("A") == false)
  }

  @Test
  func visibility() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A"])
    snapshot.append(["A1"], to: "A")
    snapshot.append(["A1a"], to: "A1")

    #expect(snapshot.isVisible("A") == true)
    #expect(snapshot.isVisible("A1") == false)
    #expect(snapshot.isVisible("A1a") == false)
    #expect(snapshot.visibleItems == ["A"])

    snapshot.expand(["A"])
    #expect(snapshot.isVisible("A1") == true)
    #expect(snapshot.isVisible("A1a") == false)
    #expect(snapshot.visibleItems == ["A", "A1"])

    snapshot.expand(["A1"])
    #expect(snapshot.isVisible("A1a") == true)
    #expect(snapshot.visibleItems == ["A", "A1", "A1a"])
  }

  @Test
  func deleteItems() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A", "B"])
    snapshot.append(["A1"], to: "A")
    snapshot.delete(["A"])
    #expect(snapshot.items == ["B"])
    #expect(snapshot.contains("A") == false)
    #expect(snapshot.contains("A1") == false)
  }

  @Test
  func containsItem() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A"])
    #expect(snapshot.contains("A") == true)
    #expect(snapshot.contains("B") == false)
  }

  @Test
  func insertBeforeAndAfter() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A", "C"])
    snapshot.insert(["B"], before: "C")
    #expect(snapshot.items == ["A", "B", "C"])
    snapshot.insert(["D"], after: "C")
    #expect(snapshot.items == ["A", "B", "C", "D"])
  }

  @Test
  func subSnapshot() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A"])
    snapshot.append(["A1", "A2"], to: "A")
    snapshot.append(["A1a"], to: "A1")

    let sub = snapshot.snapshot(of: "A", includingParent: true)
    #expect(sub.items.contains("A"))
    #expect(sub.items.contains("A1"))
    #expect(sub.items.contains("A1a"))
    #expect(sub.items.contains("A2"))

    let subWithoutParent = snapshot.snapshot(of: "A", includingParent: false)
    #expect(subWithoutParent.items.contains("A") == false)
    #expect(subWithoutParent.items.contains("A1"))
  }

  @Test
  func subSnapshotOfNestedChildHasCorrectParentMap() {
    // Tree: Root > A > A1 > A1a
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["Root"])
    snapshot.append(["A"], to: "Root")
    snapshot.append(["A1"], to: "A")
    snapshot.append(["A1a"], to: "A1")
    snapshot.expand(["Root", "A", "A1"])

    // Extract subtree rooted at "A" (including "A" as root of new snapshot)
    let sub = snapshot.snapshot(of: "A", includingParent: true)

    // "A" should be a root in the sub-snapshot (no dangling reference to "Root")
    #expect(sub.parent(of: "A") == nil)
    #expect(sub.rootItems == ["A"])
    #expect(sub.level(of: "A") == 0)
    #expect(sub.level(of: "A1") == 1)
    #expect(sub.level(of: "A1a") == 2)

    // Hierarchy should be preserved within the subtree
    #expect(sub.parent(of: "A1") == "A")
    #expect(sub.parent(of: "A1a") == "A1")

    // Items outside the subtree should not be present
    #expect(sub.contains("Root") == false)
  }

  @Test
  func subSnapshotExcludingParentHasCorrectRoots() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["Root"])
    snapshot.append(["A", "B"], to: "Root")
    snapshot.append(["A1"], to: "A")
    snapshot.expand(["Root", "A"])

    // Extract children of "Root" without "Root" itself
    let sub = snapshot.snapshot(of: "Root", includingParent: false)
    #expect(sub.contains("Root") == false)
    #expect(sub.contains("A"))
    #expect(sub.contains("B"))
    #expect(sub.contains("A1"))
    // A and B should be roots in the sub-snapshot since Root is excluded
    #expect(sub.parent(of: "A") == nil)
    #expect(sub.parent(of: "B") == nil)
    #expect(sub.parent(of: "A1") == "A")
  }

  @Test
  func subSnapshotPreservesExpansionState() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A"])
    snapshot.append(["A1"], to: "A")
    snapshot.append(["A1a"], to: "A1")
    snapshot.expand(["A"])
    // A1 is NOT expanded

    let sub = snapshot.snapshot(of: "A", includingParent: true)
    #expect(sub.isExpanded("A") == true)
    #expect(sub.isExpanded("A1") == false)
    // A1a is not visible because A1 is collapsed
    #expect(sub.visibleItems == ["A", "A1"])
  }

  @Test
  func subSnapshotDoesNotIncludeOutOfTreeChildren() {
    // Children map should be filtered to only items in the sub-snapshot
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["Root"])
    snapshot.append(["A", "B"], to: "Root")
    snapshot.append(["A1"], to: "A")
    snapshot.append(["B1"], to: "B")

    let sub = snapshot.snapshot(of: "A", includingParent: true)
    #expect(sub.contains("A"))
    #expect(sub.contains("A1"))
    #expect(!sub.contains("B"))
    #expect(!sub.contains("B1"))
    #expect(!sub.contains("Root"))
  }

  @Test
  func deleteParentLeavesNoOrphanedReferences() {
    // Delete a parent and verify that children are also removed,
    // and no dangling parent references remain.
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A", "B"])
    snapshot.append(["A1", "A2"], to: "A")
    snapshot.append(["A1a"], to: "A1")
    snapshot.expand(["A", "A1"])

    // Delete the parent "A" — children should cascade
    snapshot.delete(["A"])
    #expect(!snapshot.contains("A"))
    #expect(!snapshot.contains("A1"))
    #expect(!snapshot.contains("A2"))
    #expect(!snapshot.contains("A1a"))
    #expect(snapshot.items == ["B"])

    // "B" should still be a valid root
    #expect(snapshot.parent(of: "B") == nil)
    #expect(snapshot.rootItems == ["B"])
  }

  @Test
  func sendableConformance() {
    let snapshot = DiffableDataSourceSectionSnapshot<String>()
    let _: any Sendable = snapshot
  }

  @Test
  func childrenOfParent() {
    var snapshot = DiffableDataSourceSectionSnapshot<String>()
    snapshot.append(["A"])
    snapshot.append(["A1", "A2"], to: "A")
    snapshot.append(["A1a"], to: "A1")

    #expect(snapshot.children(of: "A") == ["A1", "A2"])
    #expect(snapshot.children(of: "A1") == ["A1a"])
    #expect(snapshot.children(of: "A2").isEmpty)
    #expect(snapshot.children(of: "A1a").isEmpty)
  }

  @Test
  func childrenOfNonexistentItem() {
    let snapshot = DiffableDataSourceSectionSnapshot<String>()
    #expect(snapshot.children(of: "missing").isEmpty)
  }
}
