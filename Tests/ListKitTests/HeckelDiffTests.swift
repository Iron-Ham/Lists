@testable import ListKit
import Testing

struct HeckelDiffTests {
    /// Test empty to populated
    @Test func emptyToPopulated() {
        let result = HeckelDiff.diff(old: [Int](), new: [1, 2, 3])
        #expect(result.deletes.isEmpty)
        #expect(result.inserts == [0, 1, 2])
        #expect(result.moves.isEmpty)
    }

    /// Test populated to empty
    @Test func populatedToEmpty() {
        let result = HeckelDiff.diff(old: [1, 2, 3], new: [Int]())
        #expect(result.deletes == [0, 1, 2])
        #expect(result.inserts.isEmpty)
        #expect(result.moves.isEmpty)
    }

    /// Test no change
    @Test func noChange() {
        let result = HeckelDiff.diff(old: [1, 2, 3], new: [1, 2, 3])
        #expect(result.deletes.isEmpty)
        #expect(result.inserts.isEmpty)
        #expect(result.moves.isEmpty)
        #expect(result.matched.count == 3)
    }

    /// Test pure inserts (add to middle)
    @Test func pureInserts() {
        let result = HeckelDiff.diff(old: [1, 3], new: [1, 2, 3])
        #expect(result.deletes.isEmpty)
        #expect(result.inserts == [1])
        // 1 and 3 are matched, no moves because 1 stays at 0 and 3 goes from index 1 to index 2
    }

    /// Test pure deletes
    @Test func pureDeletes() {
        let result = HeckelDiff.diff(old: [1, 2, 3], new: [1, 3])
        #expect(result.deletes == [1])
        #expect(result.inserts.isEmpty)
    }

    /// Test single move
    @Test func singleMove() {
        let result = HeckelDiff.diff(old: [1, 2, 3], new: [3, 1, 2])
        // All items are unique, so they should be matched
        // 1: old=0, new=1 → move
        // 2: old=1, new=2 → move
        // 3: old=2, new=0 → move
        #expect(result.deletes.isEmpty)
        #expect(result.inserts.isEmpty)
        #expect(result.moves.count == 3)
    }

    /// Test interleaved changes
    @Test func interleavedChanges() {
        let result = HeckelDiff.diff(old: [1, 2, 3, 4, 5], new: [2, 4, 6])
        // 1, 3, 5 deleted; 6 inserted; 2 and 4 survive
        #expect(result.deletes.sorted() == [0, 2, 4])
        #expect(result.inserts == [2])
    }

    /// Test with duplicates (duplicates can't be uniquely matched)
    @Test func withDuplicates() {
        let result = HeckelDiff.diff(old: [1, 1, 2], new: [1, 2, 1])
        // Duplicated '1' has many in both old and new, so it won't be uniquely matched
        // Only '2' is unique in both (old:2, new:1)
        // The two 1s will be matched via expansion from '2'
        // Verify: no crash and reasonable result
        let totalOps = result.deletes.count + result.inserts.count + result.moves.count + result.matched.count
        #expect(totalOps > 0)
    }

    /// Test both arrays empty
    @Test func bothEmpty() {
        let result = HeckelDiff.diff(old: [Int](), new: [Int]())
        #expect(result.deletes.isEmpty)
        #expect(result.inserts.isEmpty)
        #expect(result.moves.isEmpty)
        #expect(result.matched.isEmpty)
    }

    /// Test single element arrays
    @Test func singleElements() {
        let result = HeckelDiff.diff(old: [1], new: [2])
        #expect(result.deletes == [0])
        #expect(result.inserts == [0])
    }

    /// Test with strings
    @Test func withStrings() {
        let result = HeckelDiff.diff(old: ["a", "b", "c"], new: ["a", "c", "d"])
        #expect(result.deletes == [1]) // "b" deleted
        #expect(result.inserts == [2]) // "d" inserted
    }

    /// Performance test with large arrays
    @Test func largeArrayPerformance() {
        let old = Array(0 ..< 10000)
        let new = Array(5000 ..< 15000)
        let result = HeckelDiff.diff(old: old, new: new)
        // First 5000 elements deleted, last 5000 inserted
        #expect(result.deletes.count == 5000)
        #expect(result.inserts.count == 5000)
        #expect(result.matched.count == 5000)
    }
}
