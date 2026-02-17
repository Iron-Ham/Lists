// ABOUTME: Tests for OutlineItemBuilder result builder: leaf nodes, nesting, and control flow.
// ABOUTME: Also tests OutlineList.setItems with the builder DSL.
import Testing
import UIKit
@testable import ListKit
@testable import Lists

// MARK: - OutlineItemBuilderTests

struct OutlineItemBuilderTests {
  @Test
  func builderCreatesLeafNodes() {
    let items = buildOutline {
      OutlineItem(item: "A")
      OutlineItem(item: "B")
      OutlineItem(item: "C")
    }

    #expect(items.count == 3)
    #expect(items[0].item == "A")
    #expect(items[0].children.isEmpty)
    #expect(items[1].item == "B")
    #expect(items[2].item == "C")
  }

  @Test
  func builderCreatesNestedHierarchy() {
    let items = buildOutline {
      OutlineItem(item: "Root", isExpanded: true) {
        OutlineItem(item: "Child1")
        OutlineItem(item: "Child2") {
          OutlineItem(item: "Grandchild")
        }
      }
    }

    #expect(items.count == 1)
    #expect(items[0].item == "Root")
    #expect(items[0].isExpanded == true)
    #expect(items[0].children.count == 2)
    #expect(items[0].children[0].item == "Child1")
    #expect(items[0].children[0].children.isEmpty)
    #expect(items[0].children[1].item == "Child2")
    #expect(items[0].children[1].children.count == 1)
    #expect(items[0].children[1].children[0].item == "Grandchild")
  }

  @Test
  func builderSupportsConditionals() {
    let showOptional = true

    let items = buildOutline {
      OutlineItem(item: "Always")
      if showOptional {
        OutlineItem(item: "Sometimes")
      }
    }

    #expect(items.count == 2)
  }

  @Test
  func builderOmitsConditionals() {
    let showOptional = false

    let items = buildOutline {
      OutlineItem(item: "Always")
      if showOptional {
        OutlineItem(item: "Sometimes")
      }
    }

    #expect(items.count == 1)
    #expect(items[0].item == "Always")
  }

  @Test
  func builderSupportsIfElse() {
    let useA = false

    let items = buildOutline {
      if useA {
        OutlineItem(item: "A")
      } else {
        OutlineItem(item: "B")
      }
    }

    #expect(items.count == 1)
    #expect(items[0].item == "B")
  }

  @Test
  func builderSupportsLoops() {
    let names = ["A", "B", "C"]

    let items = buildOutline {
      for name in names {
        OutlineItem(item: name)
      }
    }

    #expect(items.count == 3)
    #expect(items.map(\.item) == ["A", "B", "C"])
  }

  @Test
  func builderSupportsArrayExpression() {
    let children = [OutlineItem(item: "X"), OutlineItem(item: "Y")]

    let items = buildOutline {
      children
    }

    #expect(items.count == 2)
  }

  @MainActor
  @Test
  func outlineListSetItemsWithBuilder() async {
    let list = OutlineList<TextItem>()

    let fileA = TextItem(text: "FileA")
    let fileB = TextItem(text: "FileB")
    let folder = TextItem(text: "Folder")

    await list.setItems(animatingDifferences: false) {
      OutlineItem(item: folder, isExpanded: true) {
        OutlineItem(item: fileA)
        OutlineItem(item: fileB)
      }
    }

    let snapshot = list.snapshot()
    #expect(snapshot.numberOfItems == 3)
  }
}

// MARK: - Helpers

private func buildOutline(
  @OutlineItemBuilder<String> content: () -> [OutlineItem<String>]
) -> [OutlineItem<String>] {
  content()
}
