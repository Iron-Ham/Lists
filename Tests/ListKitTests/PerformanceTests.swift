// ABOUTME: Performance tests verifying O(n) scaling for HeckelDiff and SectionedDiff.
// ABOUTME: Tests up to 100k elements with timing assertions to catch regressions.
import Foundation
import Testing
@testable import ListKit

struct PerformanceTests {
  @Test
  func heckelDiff10kElements() {
    let old = Array(0 ..< 10000)
    let new = Array(5000 ..< 15000) // 5k deletes, 5k matches, 5k inserts

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = HeckelDiff.diff(old: old, new: new)
    }

    // Heckel is O(n) — 10k elements should complete well under 100ms
    #expect(elapsed < .milliseconds(100), "Heckel diff of 10k elements took \(elapsed)")
  }

  @Test
  func heckelDiff50kElements() {
    let old = Array(0 ..< 50000)
    let new = Array(25000 ..< 75000)

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = HeckelDiff.diff(old: old, new: new)
    }

    // 50k should still be fast — well under 500ms
    #expect(elapsed < .milliseconds(500), "Heckel diff of 50k elements took \(elapsed)")
  }

  @Test
  func heckelDiff100kElements() {
    let old = Array(0 ..< 100_000)
    let new = Array(50000 ..< 150_000)

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = HeckelDiff.diff(old: old, new: new)
    }

    // 100k — O(n) means this scales linearly
    #expect(elapsed < .seconds(1), "Heckel diff of 100k elements took \(elapsed)")
  }

  @Test
  func heckelDiffFullShuffle10k() {
    let old = Array(0 ..< 10000)
    var new = old
    // Deterministic shuffle using a seeded approach
    for i in stride(from: new.count - 1, through: 1, by: -1) {
      let j = i * 7 % (i + 1)
      new.swapAt(i, j)
    }

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = HeckelDiff.diff(old: old, new: new)
    }

    #expect(elapsed < .milliseconds(100), "Heckel diff shuffle 10k took \(elapsed)")
  }

  @Test
  func heckelDiffNoChange10k() {
    let items = Array(0 ..< 10000)

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = HeckelDiff.diff(old: items, new: items)
    }

    // No-change case should be fastest
    #expect(elapsed < .milliseconds(50), "Heckel diff no-change 10k took \(elapsed)")
  }

  @Test
  func sectionedDiffSingleSection10kItems() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["main"])
    old.appendItems(Array(0 ..< 10000), toSection: "main")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["main"])
    new.appendItems(Array(5000 ..< 15000), toSection: "main")

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = SectionedDiff.diff(old: old, new: new)
    }

    #expect(elapsed < .milliseconds(200), "Sectioned diff 10k items took \(elapsed)")
  }

  @Test
  func sectionedDiff100Sections100ItemsEach() {
    var old = DiffableDataSourceSnapshot<Int, Int>()
    var new = DiffableDataSourceSnapshot<Int, Int>()
    var counter = 0

    // Build 100 sections with 100 items each = 10k total items
    for section in 0 ..< 100 {
      old.appendSections([section])
      new.appendSections([section])
      let oldItems = Array(counter ..< counter + 100)
      // Shift items: some removed, some added
      let newItems = Array(counter + 50 ..< counter + 150)
      old.appendItems(oldItems, toSection: section)
      new.appendItems(newItems, toSection: section)
      counter += 200 // avoid collisions between sections
    }

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = SectionedDiff.diff(old: old, new: new)
    }

    #expect(elapsed < .milliseconds(300), "Sectioned diff 100 sections × 100 items took \(elapsed)")
  }

  @Test
  func sectionedDiffSectionReorder() {
    var old = DiffableDataSourceSnapshot<Int, Int>()
    var new = DiffableDataSourceSnapshot<Int, Int>()
    var counter = 0

    // 50 sections, reverse their order
    for section in 0 ..< 50 {
      old.appendSections([section])
      let items = Array(counter ..< counter + 100)
      old.appendItems(items, toSection: section)
      counter += 100
    }

    counter = 0
    for section in (0 ..< 50).reversed() {
      new.appendSections([section])
      let items = Array(counter ..< counter + 100)
      new.appendItems(items, toSection: section)
      counter += 100
    }

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = SectionedDiff.diff(old: old, new: new)
    }

    #expect(elapsed < .milliseconds(200), "Sectioned diff section reorder took \(elapsed)")
  }

  @Test
  func sectionedDiffCrossSectionMoves() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems(Array(0 ..< 5000), toSection: "A")
    old.appendItems(Array(5000 ..< 10000), toSection: "B")

    // Move half the items across sections
    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems(Array(2500 ..< 7500), toSection: "A")
    new.appendItems(Array(0 ..< 2500) + Array(7500 ..< 10000), toSection: "B")

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = SectionedDiff.diff(old: old, new: new)
    }

    #expect(elapsed < .milliseconds(300), "Sectioned diff cross-section moves took \(elapsed)")
  }

  @Test
  func snapshotBuildAndAppend10kItems() {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
      var snapshot = DiffableDataSourceSnapshot<String, Int>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(Array(0 ..< 10000), toSection: "main")
    }

    #expect(elapsed < .milliseconds(50), "Snapshot build 10k items took \(elapsed)")
  }

  @Test
  func snapshotBuildMultipleSections() {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
      var snapshot = DiffableDataSourceSnapshot<Int, Int>()
      var counter = 0
      for section in 0 ..< 100 {
        snapshot.appendSections([section])
        snapshot.appendItems(Array(counter ..< counter + 100), toSection: section)
        counter += 100
      }
    }

    #expect(elapsed < .milliseconds(50), "Snapshot build 100 sections took \(elapsed)")
  }

  @Test
  func diffScalesLinearly() {
    // Measure diff at two sizes and verify it roughly scales linearly
    let small = 5000
    let large = 20000

    let clock = ContinuousClock()

    let smallTime = clock.measure {
      let old = Array(0 ..< small)
      let new = Array(small / 2 ..< small + small / 2)
      _ = HeckelDiff.diff(old: old, new: new)
    }

    let largeTime = clock.measure {
      let old = Array(0 ..< large)
      let new = Array(large / 2 ..< large + large / 2)
      _ = HeckelDiff.diff(old: old, new: new)
    }

    // With 4x the input, an O(n) algorithm should take roughly 4x the time
    // Allow generous margin (8x) to account for variance, caching, etc.
    let ratio = Double(largeTime.components.attoseconds) / Double(smallTime.components.attoseconds)
    #expect(ratio < 8.0, "Diff scaling ratio \(ratio)x for 4x input — expected < 8x for O(n)")
  }

  @Test
  func diffWithManyDuplicates() {
    // Duplicates stress the Heckel algorithm since it can't uniquely match them
    let old = (0 ..< 1000).flatMap { [$0, $0, $0] } // 3k items, each appearing 3x
    let new = (500 ..< 1500).flatMap { [$0, $0, $0] }

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = HeckelDiff.diff(old: old, new: new)
    }

    #expect(elapsed < .milliseconds(100), "Diff with duplicates took \(elapsed)")
  }

  @Test
  func diffAlternatingInsertDelete() {
    // Alternating pattern: old has evens, new has odds
    let old = stride(from: 0, to: 10000, by: 2).map(\.self) // 5k evens
    let new = stride(from: 1, to: 10001, by: 2).map(\.self) // 5k odds

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = HeckelDiff.diff(old: old, new: new)
    }

    // Complete replacement — all deletes + all inserts
    #expect(elapsed < .milliseconds(100), "Alternating insert/delete diff took \(elapsed)")
  }
}
