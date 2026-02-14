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
  func sendableConformance() {
    let snapshot = DiffableDataSourceSectionSnapshot<String>()
    let _: any Sendable = snapshot
  }
}
