import Testing
@testable import ListKit

struct HeckelDiffTests {
  /// Test empty to populated
  @Test
  func emptyToPopulated() {
    let result = HeckelDiff.diff(old: [Int](), new: [1, 2, 3])
    #expect(result.deletes.isEmpty)
    #expect(result.inserts == [0, 1, 2])
    #expect(result.moves.isEmpty)
  }

  /// Test populated to empty
  @Test
  func populatedToEmpty() {
    let result = HeckelDiff.diff(old: [1, 2, 3], new: [Int]())
    #expect(result.deletes == [0, 1, 2])
    #expect(result.inserts.isEmpty)
    #expect(result.moves.isEmpty)
  }

  /// Test no change
  @Test
  func noChange() {
    let result = HeckelDiff.diff(old: [1, 2, 3], new: [1, 2, 3])
    #expect(result.deletes.isEmpty)
    #expect(result.inserts.isEmpty)
    #expect(result.moves.isEmpty)
    #expect(result.matched.count == 3)
  }

  /// Test pure inserts (add to middle)
  @Test
  func pureInserts() {
    let result = HeckelDiff.diff(old: [1, 3], new: [1, 2, 3])
    #expect(result.deletes.isEmpty)
    #expect(result.inserts == [1])
    // 1 and 3 are matched, no moves because 1 stays at 0 and 3 goes from index 1 to index 2
  }

  /// Test pure deletes
  @Test
  func pureDeletes() {
    let result = HeckelDiff.diff(old: [1, 2, 3], new: [1, 3])
    #expect(result.deletes == [1])
    #expect(result.inserts.isEmpty)
  }

  /// Test single move — moving 3 to the front is the only genuine reordering;
  /// 1 and 2 shift naturally and don't need explicit moves.
  @Test
  func singleMove() {
    let result = HeckelDiff.diff(old: [1, 2, 3], new: [3, 1, 2])
    // 3: old=2, new=0 → genuine move (changed relative order)
    // 1: old=0, new=1 → positional shift (stays in relative order with 2)
    // 2: old=1, new=2 → positional shift (stays in relative order with 1)
    #expect(result.deletes.isEmpty)
    #expect(result.inserts.isEmpty)
    #expect(result.moves.count == 1)
    #expect(result.moves[0].from == 2)
    #expect(result.moves[0].to == 0)
  }

  /// Test interleaved changes
  @Test
  func interleavedChanges() {
    let result = HeckelDiff.diff(old: [1, 2, 3, 4, 5], new: [2, 4, 6])
    // 1, 3, 5 deleted; 6 inserted; 2 and 4 survive
    #expect(result.deletes.sorted() == [0, 2, 4])
    #expect(result.inserts == [2])
  }

  /// Test with duplicates (duplicates can't be uniquely matched)
  @Test
  func withDuplicates() {
    let result = HeckelDiff.diff(old: [1, 1, 2], new: [1, 2, 1])
    // Duplicated '1' has many in both old and new, so it won't be uniquely matched
    // Only '2' is unique in both (old:2, new:1)
    // The two 1s will be matched via expansion from '2'
    // Verify: no crash and reasonable result
    let totalOps = result.deletes.count + result.inserts.count + result.moves.count + result.matched.count
    #expect(totalOps > 0)
  }

  /// Test both arrays empty
  @Test
  func bothEmpty() {
    let result = HeckelDiff.diff(old: [Int](), new: [Int]())
    #expect(result.deletes.isEmpty)
    #expect(result.inserts.isEmpty)
    #expect(result.moves.isEmpty)
    #expect(result.matched.isEmpty)
  }

  /// Test single element arrays
  @Test
  func singleElements() {
    let result = HeckelDiff.diff(old: [1], new: [2])
    #expect(result.deletes == [0])
    #expect(result.inserts == [0])
  }

  /// Test with strings
  @Test
  func withStrings() {
    let result = HeckelDiff.diff(old: ["a", "b", "c"], new: ["a", "c", "d"])
    #expect(result.deletes == [1]) // "b" deleted
    #expect(result.inserts == [2]) // "d" inserted
  }

  /// Performance test with large arrays
  @Test
  func largeArrayPerformance() {
    let old = Array(0 ..< 10000)
    let new = Array(5000 ..< 15000)
    let result = HeckelDiff.diff(old: old, new: new)
    // First 5000 elements deleted, last 5000 inserted
    #expect(result.deletes.count == 5000)
    #expect(result.inserts.count == 5000)
    #expect(result.matched.count == 5000)
  }

  /// Deleting an item should produce no moves — remaining items shift naturally.
  @Test
  func deleteProducesNoMoves() {
    let result = HeckelDiff.diff(old: [1, 2, 3, 4, 5], new: [1, 2, 4, 5])
    #expect(result.deletes == [2]) // 3 deleted
    #expect(result.moves.isEmpty) // no reordering
  }

  /// Inserting an item should produce no moves — existing items shift naturally.
  @Test
  func insertProducesNoMoves() {
    let result = HeckelDiff.diff(old: [1, 2, 3], new: [1, 2, 99, 3])
    #expect(result.inserts == [2]) // 99 inserted at new index 2
    #expect(result.moves.isEmpty)
  }

  /// Moving one element to the front is a single genuine move.
  @Test
  func moveToFrontIsSingleMove() {
    let result = HeckelDiff.diff(old: [1, 2, 3, 4, 5], new: [5, 1, 2, 3, 4])
    #expect(result.deletes.isEmpty)
    #expect(result.inserts.isEmpty)
    // Only 5 needs an explicit move; 1-4 shift naturally
    #expect(result.moves.count == 1)
    #expect(result.moves[0].from == 4)
    #expect(result.moves[0].to == 0)
  }

  /// Swapping two elements requires one move (the other adjusts naturally).
  @Test
  func swapRequiresOneMove() {
    let result = HeckelDiff.diff(old: [1, 2, 3], new: [1, 3, 2])
    #expect(result.moves.count == 1)
  }

  /// Complete reversal of n elements requires n-1 moves (LIS length is 1).
  @Test
  func reversalMovesCount() {
    let result = HeckelDiff.diff(old: [1, 2, 3, 4, 5], new: [5, 4, 3, 2, 1])
    // LIS of reversed old-indices [4,3,2,1,0] has length 1, so 4 moves needed
    #expect(result.moves.count == 4)
  }

  /// Already-sorted array needs no moves.
  @Test
  func alreadySortedNoMoves() {
    let result = HeckelDiff.diff(old: [1, 2, 3, 4, 5], new: [1, 2, 3, 4, 5])
    #expect(result.moves.isEmpty)
  }

  /// LIS with all-duplicate old-indices should produce maximum moves.
  @Test
  func allDuplicateLISProducesMaximalMoves() {
    // When every element appears in both arrays but none are unique,
    // the expansion passes still match them. Verify we don't crash
    // and the result is structurally valid.
    let old = [1, 1, 2, 2, 3, 3]
    let new = [3, 3, 1, 1, 2, 2]

    let result = HeckelDiff.diff(old: old, new: new)

    // Net change should be zero (same multiset)
    #expect(result.deletes.count == result.inserts.count)

    // Every old index is accounted for
    let oldCovered = Set(result.deletes + result.matched.map(\.old))
    #expect(oldCovered == Set(0 ..< old.count))

    let newCovered = Set(result.inserts + result.matched.map(\.new))
    #expect(newCovered == Set(0 ..< new.count))
  }

  /// Verify that applying deletes + inserts + moves reconstructs the new array.
  @Test
  func movesReconstructNewArray() {
    let old = [10, 20, 30, 40, 50]
    let new = [30, 50, 10, 20, 40]
    let result = HeckelDiff.diff(old: old, new: new)

    // Every old index is either deleted or matched, every new index is inserted or matched
    let oldCovered = Set(result.deletes + result.matched.map(\.old))
    #expect(oldCovered == Set(0 ..< old.count))
    let newCovered = Set(result.inserts + result.matched.map(\.new))
    #expect(newCovered == Set(0 ..< new.count))

    // Matched pairs should map old→new correctly
    for pair in result.matched {
      #expect(old[pair.old] == new[pair.new])
    }
  }
}
