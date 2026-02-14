import Foundation
import Testing
@testable import ListKit
@testable import Lists

struct ListsPerformanceTests {
  @Test
  func dslBuild100Sections100Items() {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = DiffableDataSourceSnapshot<Int, NumberItem> {
        for section in 0 ..< 100 {
          SnapshotSection(section) {
            (0 ..< 100).map { NumberItem(value: section * 1000 + $0) }
          }
        }
      }
    }

    #expect(elapsed < .milliseconds(100), "DSL build 100×100 took \(elapsed)")
  }

  @Test
  func dslBuildSingleSection10kItems() {
    let items = (0 ..< 10000).map { NumberItem(value: $0) }

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      _ = DiffableDataSourceSnapshot<String, NumberItem> {
        SnapshotSection("main") {
          items
        }
      }
    }

    #expect(elapsed < .milliseconds(50), "DSL build 10k items took \(elapsed)")
  }

  @Test
  func dslBuildPerformanceMatchesManual() {
    let itemCount = 10000
    let items = (0 ..< itemCount).map { NumberItem(value: $0) }

    let clock = ContinuousClock()

    let manualTime = clock.measure {
      var snapshot = DiffableDataSourceSnapshot<String, NumberItem>()
      snapshot.appendSections(["main"])
      snapshot.appendItems(items, toSection: "main")
    }

    let dslTime = clock.measure {
      _ = DiffableDataSourceSnapshot<String, NumberItem> {
        SnapshotSection("main") {
          items
        }
      }
    }

    // DSL should add minimal overhead — within 3x of manual
    let ratio = Double(dslTime.components.attoseconds) / max(Double(manualTime.components.attoseconds), 1)
    #expect(ratio < 3.0, "DSL was \(ratio)x slower than manual build")
  }

  @Test
  func fullPipelineBuildAndDiff10k() {
    let oldItems = (0 ..< 10000).map { NumberItem(value: $0) }
    let newItems = (5000 ..< 15000).map { NumberItem(value: $0) }

    let clock = ContinuousClock()
    let elapsed = clock.measure {
      let old = DiffableDataSourceSnapshot<String, NumberItem> {
        SnapshotSection("main") { oldItems }
      }
      let new = DiffableDataSourceSnapshot<String, NumberItem> {
        SnapshotSection("main") { newItems }
      }
      _ = SectionedDiff.diff(old: old, new: new)
    }

    #expect(elapsed < .milliseconds(300), "Full pipeline 10k took \(elapsed)")
  }

  @Test
  func fullPipelineMultiSectionBuildAndDiff() {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
      var oldSections = [SnapshotSection<Int, NumberItem>]()
      var newSections = [SnapshotSection<Int, NumberItem>]()

      for section in 0 ..< 50 {
        let base = section * 200
        oldSections.append(SnapshotSection(section, items: (base ..< base + 100).map { NumberItem(value: $0) }))
        newSections.append(SnapshotSection(section, items: (base + 50 ..< base + 150).map { NumberItem(value: $0) }))
      }

      var old = DiffableDataSourceSnapshot<Int, NumberItem>()
      for section in oldSections {
        old.appendSections([section.id])
        old.appendItems(section.items, toSection: section.id)
      }

      var new = DiffableDataSourceSnapshot<Int, NumberItem>()
      for section in newSections {
        new.appendSections([section.id])
        new.appendItems(section.items, toSection: section.id)
      }

      _ = SectionedDiff.diff(old: old, new: new)
    }

    #expect(elapsed < .milliseconds(200), "Full multi-section pipeline took \(elapsed)")
  }

  @Test
  func sectionModelBuild10Sections1000Items() {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
      var snapshot = DiffableDataSourceSnapshot<Int, NumberItem>()
      for section in 0 ..< 10 {
        let base = section * 1000
        let model = SectionModel(
          id: section,
          items: (base ..< base + 1000).map { NumberItem(value: $0) },
          header: "Section \(section)"
        )
        snapshot.appendSections([model.id])
        snapshot.appendItems(model.items, toSection: model.id)
      }
    }

    #expect(elapsed < .milliseconds(50), "SectionModel build 10×1000 took \(elapsed)")
  }

  @Test
  func repeatedDiffsSimulatingScrollUpdates() {
    // Simulate a paginated list that appends items over time
    var current = DiffableDataSourceSnapshot<String, NumberItem>()
    current.appendSections(["main"])
    current.appendItems((0 ..< 100).map { NumberItem(value: $0) }, toSection: "main")

    let clock = ContinuousClock()
    var totalElapsed = Duration.zero

    // 50 incremental updates (simulating pagination)
    for page in 1 ... 50 {
      let base = page * 100
      var next = current
      next.appendItems((base ..< base + 100).map { NumberItem(value: $0) }, toSection: "main")

      let elapsed = clock.measure {
        _ = SectionedDiff.diff(old: current, new: next)
      }
      totalElapsed += elapsed
      current = next
    }

    // 50 diffs, growing from 100 to 5100 items — should be fast overall
    #expect(totalElapsed < .seconds(1), "50 incremental diffs totaled \(totalElapsed)")
  }

  @Test
  func repeatedDiffsSimulatingShuffle() {
    let items = (0 ..< 1000).map { NumberItem(value: $0) }

    var current = DiffableDataSourceSnapshot<String, NumberItem>()
    current.appendSections(["main"])
    current.appendItems(items, toSection: "main")

    let clock = ContinuousClock()
    var totalElapsed = Duration.zero

    // 20 shuffles
    for i in 0 ..< 20 {
      var shuffled = items
      // Deterministic shuffle
      for j in stride(from: shuffled.count - 1, through: 1, by: -1) {
        let k = (j * (i + 3) * 7) % (j + 1)
        shuffled.swapAt(j, k)
      }

      var next = DiffableDataSourceSnapshot<String, NumberItem>()
      next.appendSections(["main"])
      next.appendItems(shuffled, toSection: "main")

      let elapsed = clock.measure {
        _ = SectionedDiff.diff(old: current, new: next)
      }
      totalElapsed += elapsed
      current = next
    }

    #expect(totalElapsed < .seconds(1), "20 shuffle diffs totaled \(totalElapsed)")
  }
}
