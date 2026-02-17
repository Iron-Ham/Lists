// ABOUTME: Tests for SnapshotBuilder DSL: sections, items, conditionals, loops, and headers.
// ABOUTME: Also tests SectionModel builder init, snapshot contains helpers, and availability.
import Testing
import UIKit
@testable import ListKit
@testable import Lists

struct SnapshotBuilderTests {
  @Test
  func buildSingleSection() {
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

  @Test
  func buildMultipleSections() {
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

  @Test
  func conditionalSection() {
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

  @Test
  func conditionalSectionOmitted() {
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

  @Test
  func conditionalItems() {
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

  @Test
  func loopSections() {
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

  @Test
  func arrayPassthroughInItems() {
    let items = [NumberItem(value: 10), NumberItem(value: 20)]

    let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
      SnapshotSection("main") {
        items
      }
    }

    #expect(snapshot.itemIdentifiers == items)
  }

  @Test
  func emptyBuilder() {
    let snapshot = DiffableDataSourceSnapshot<String, NumberItem> { }

    #expect(snapshot.numberOfSections == 0)
    #expect(snapshot.numberOfItems == 0)
  }

  @Test
  func sectionInitWithItemsArray() {
    let items = [NumberItem(value: 1), NumberItem(value: 2)]
    let section = SnapshotSection("test", items: items)

    #expect(section.id == "test")
    #expect(section.items == items)
  }

  @Test
  func ifElseSections() {
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

  @Test
  func ifElseItems() {
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

  @Test
  func availabilityCheckInItems() {
    let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
      SnapshotSection("main") {
        NumberItem(value: 1)
        if #available(iOS 17, *) {
          NumberItem(value: 2)
        }
      }
    }

    #expect(snapshot.numberOfItems == 2)
  }

  @Test
  func availabilityCheckInSections() {
    let snapshot = DiffableDataSourceSnapshot<String, NumberItem> {
      SnapshotSection("always") {
        NumberItem(value: 1)
      }
      if #available(iOS 17, *) {
        SnapshotSection("conditional") {
          NumberItem(value: 2)
        }
      }
    }

    #expect(snapshot.numberOfSections == 2)
  }

  @Test
  func snapshotSectionWithHeader() {
    let section = SnapshotSection<String, NumberItem>("test", header: "My Header") {
      NumberItem(value: 1)
    }

    #expect(section.id == "test")
    #expect(section.header == "My Header")
    #expect(section.footer == nil)
    #expect(section.items.count == 1)
  }

  @Test
  func snapshotSectionWithHeaderAndFooter() {
    let section = SnapshotSection<String, NumberItem>(
      "test",
      header: "Header",
      footer: "Footer"
    ) {
      NumberItem(value: 1)
      NumberItem(value: 2)
    }

    #expect(section.header == "Header")
    #expect(section.footer == "Footer")
    #expect(section.items.count == 2)
  }

  @Test
  func snapshotSectionArrayInitWithHeader() {
    let items = [NumberItem(value: 1), NumberItem(value: 2)]
    let section = SnapshotSection("test", items: items, header: "Header", footer: "Footer")

    #expect(section.header == "Header")
    #expect(section.footer == "Footer")
    #expect(section.items == items)
  }

  @Test
  func snapshotSectionDefaultsHeaderFooterToNil() {
    let section = SnapshotSection<String, NumberItem>("test") {
      NumberItem(value: 1)
    }

    #expect(section.header == nil)
    #expect(section.footer == nil)
  }

  @Test
  func sectionModelBuilderInit() {
    let section = SectionModel(id: "friends", header: "Friends") {
      NumberItem(value: 1)
      NumberItem(value: 2)
      NumberItem(value: 3)
    }

    #expect(section.id == "friends")
    #expect(section.header == "Friends")
    #expect(section.footer == nil)
    #expect(section.items.count == 3)
  }

  @Test
  func sectionModelBuilderWithConditional() {
    let showExtra = true

    let section = SectionModel(id: "test") {
      NumberItem(value: 1)
      if showExtra {
        NumberItem(value: 2)
      }
    }

    #expect(section.items.count == 2)
  }

  @Test
  func sectionModelBuilderWithLoop() {
    let section = SectionModel(id: "test") {
      for i in 0 ..< 5 {
        NumberItem(value: i)
      }
    }

    #expect(section.items.count == 5)
  }

  @Test
  func snapshotContainsItem() {
    let item = NumberItem(value: 42)
    var snapshot = DiffableDataSourceSnapshot<String, NumberItem>()
    snapshot.appendSections(["main"])
    snapshot.appendItems([item], toSection: "main")

    #expect(snapshot.contains(item))
    #expect(!snapshot.contains(NumberItem(value: 99)))
  }

  @Test
  func snapshotContainsSection() {
    var snapshot = DiffableDataSourceSnapshot<String, NumberItem>()
    snapshot.appendSections(["main", "extra"])

    #expect(snapshot.contains(section: "main"))
    #expect(snapshot.contains(section: "extra"))
    #expect(!snapshot.contains(section: "missing"))
  }
}
