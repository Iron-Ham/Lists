import Foundation
import IGListDiffKit
@testable import ListKit
import Testing

/// Benchmarks comparing ListKit's diff against IGListKit's diff algorithm.
///
/// Both libraries implement O(n) Heckel diff. IGListKit's `ListDiff` operates on
/// flat `NSArray<id<IGListDiffable>>` (Obj-C++). ListKit uses Swift generics with
/// `Hashable` value types.
///
/// For fairness, both sides perform equivalent work:
/// - IGListKit: diff two flat arrays
/// - ListKit: build two snapshots + run `SectionedDiff.diff` (full pipeline)
struct IGListDiffBenchmarks {
    // MARK: - Diff 10k: 50% overlap (5k deletes, 5k matches, 5k inserts)

    @Test func diff10kElements() {
        let old = (0 ..< 10000).map { NSNumber(value: $0) }
        let new = (5000 ..< 15000).map { NSNumber(value: $0) }

        let igTime = benchmark {
            _ = ListDiff(oldArray: old, newArray: new, option: .equality)
        }

        // ListKit: build two snapshots + diff (full pipeline)
        let lkTime = benchmark {
            var oldSnap = DiffableDataSourceSnapshot<String, Int>()
            oldSnap.appendSections(["main"])
            oldSnap.appendItems(Array(0 ..< 10000), toSection: "main")
            var newSnap = DiffableDataSourceSnapshot<String, Int>()
            newSnap.appendSections(["main"])
            newSnap.appendItems(Array(5000 ..< 15000), toSection: "main")
            _ = SectionedDiff.diff(old: oldSnap, new: newSnap)
        }

        print("Diff 10k — IGListKit: \(ms(igTime)) ms | ListKit: \(ms(lkTime)) ms")
    }

    // MARK: - Diff 50k: 50% overlap

    @Test func diff50kElements() {
        let old = (0 ..< 50000).map { NSNumber(value: $0) }
        let new = (25000 ..< 75000).map { NSNumber(value: $0) }

        let igTime = benchmark {
            _ = ListDiff(oldArray: old, newArray: new, option: .equality)
        }

        let lkTime = benchmark {
            var oldSnap = DiffableDataSourceSnapshot<String, Int>()
            oldSnap.appendSections(["main"])
            oldSnap.appendItems(Array(0 ..< 50000), toSection: "main")
            var newSnap = DiffableDataSourceSnapshot<String, Int>()
            newSnap.appendSections(["main"])
            newSnap.appendItems(Array(25000 ..< 75000), toSection: "main")
            _ = SectionedDiff.diff(old: oldSnap, new: newSnap)
        }

        print("Diff 50k — IGListKit: \(ms(igTime)) ms | ListKit: \(ms(lkTime)) ms")
    }

    // MARK: - Diff No Change (identity)

    @Test func diffNoChange10k() {
        let items = (0 ..< 10000).map { NSNumber(value: $0) }

        let igTime = benchmark {
            _ = ListDiff(oldArray: items, newArray: items, option: .equality)
        }

        let lkTime = benchmark {
            var oldSnap = DiffableDataSourceSnapshot<String, Int>()
            oldSnap.appendSections(["main"])
            oldSnap.appendItems(Array(0 ..< 10000), toSection: "main")
            var newSnap = DiffableDataSourceSnapshot<String, Int>()
            newSnap.appendSections(["main"])
            newSnap.appendItems(Array(0 ..< 10000), toSection: "main")
            _ = SectionedDiff.diff(old: oldSnap, new: newSnap)
        }

        print("Diff no-change 10k — IGListKit: \(ms(igTime)) ms | ListKit: \(ms(lkTime)) ms")
    }

    // MARK: - Diff Shuffle (all moves, no inserts/deletes)

    @Test func diffShuffle10k() {
        let old = (0 ..< 10000).map { NSNumber(value: $0) }
        var shuffled = old
        for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let j = i * 7 % (i + 1)
            shuffled.swapAt(i, j)
        }

        let igTime = benchmark {
            _ = ListDiff(oldArray: old, newArray: shuffled, option: .equality)
        }

        // Equivalent shuffle for ListKit using Int arrays
        let oldInts = Array(0 ..< 10000)
        var shuffledInts = oldInts
        for i in stride(from: shuffledInts.count - 1, through: 1, by: -1) {
            let j = i * 7 % (i + 1)
            shuffledInts.swapAt(i, j)
        }

        let lkTime = benchmark {
            var oldSnap = DiffableDataSourceSnapshot<String, Int>()
            oldSnap.appendSections(["main"])
            oldSnap.appendItems(oldInts, toSection: "main")
            var newSnap = DiffableDataSourceSnapshot<String, Int>()
            newSnap.appendSections(["main"])
            newSnap.appendItems(shuffledInts, toSection: "main")
            _ = SectionedDiff.diff(old: oldSnap, new: newSnap)
        }

        print("Diff shuffle 10k — IGListKit: \(ms(igTime)) ms | ListKit: \(ms(lkTime)) ms")
    }
}
