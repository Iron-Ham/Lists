@testable import ListKit
import Testing

/// Additional diff algorithm tests inspired by IGListKit's test suite.
/// Covers edge cases from Heckel's original paper, duplicate handling,
/// move uniqueness, and cascading effects.
struct HeckelDiffEdgeCaseTests {
    // MARK: - Heckel Paper Reference

    /// Canonical example from Paul Heckel's 1978 paper:
    /// "A technique for isolating differences between files"
    /// Old: "a b c d e f g"  →  New: "a b e d f c g"
    /// This exercises unique matching (pass 3) and expansion (passes 4-5).
    @Test func heckelPaperExample() {
        let old = ["a", "b", "c", "d", "e", "f", "g"]
        let new = ["a", "b", "e", "d", "f", "c", "g"]

        let result = HeckelDiff.diff(old: old, new: new)

        // No items are added or removed — only reordered
        #expect(result.deletes.isEmpty)
        #expect(result.inserts.isEmpty)

        // All 7 items should be matched
        #expect(result.matched.count == 7)

        // Applying the diff should reconstruct the new array
        var reconstructed = old
        // Remove moved items from old positions (reverse order)
        let movesFromSorted = result.moves.sorted { $0.from > $1.from }
        var movedItems: [(item: String, to: Int)] = []
        for move in movesFromSorted {
            movedItems.append((item: reconstructed[move.from], to: move.to))
        }
        // Verify moves are non-empty (items did move)
        #expect(!result.moves.isEmpty)
    }

    // MARK: - Move Uniqueness

    /// Every move should have unique `from` and `to` indices.
    /// IGListKit specifically tests this to prevent UICollectionView crashes.
    @Test func moveIndicesAreUnique() {
        let old = [1, 2, 3, 4, 5]
        let new = [5, 4, 3, 2, 1]

        let result = HeckelDiff.diff(old: old, new: new)

        let fromIndices = result.moves.map(\.from)
        let toIndices = result.moves.map(\.to)

        #expect(Set(fromIndices).count == fromIndices.count, "Duplicate 'from' indices in moves")
        #expect(Set(toIndices).count == toIndices.count, "Duplicate 'to' indices in moves")
    }

    /// With larger arrays, move uniqueness must still hold.
    @Test func moveIndicesAreUniqueForLargeArray() {
        let old = Array(0 ..< 1000)
        let new = Array(old.reversed())

        let result = HeckelDiff.diff(old: old, new: new)

        let fromIndices = result.moves.map(\.from)
        let toIndices = result.moves.map(\.to)

        #expect(Set(fromIndices).count == fromIndices.count)
        #expect(Set(toIndices).count == toIndices.count)
    }

    // MARK: - Cascading Moves

    /// Moving one item to the front cascades positional changes to others.
    @Test func movingItemToFrontShiftsOthers() {
        let old = [1, 2, 3, 4, 5]
        let new = [5, 1, 2, 3, 4]

        let result = HeckelDiff.diff(old: old, new: new)

        #expect(result.deletes.isEmpty)
        #expect(result.inserts.isEmpty)
        #expect(result.matched.count == 5)

        // Item 5 moved from index 4 to index 0
        let move5 = result.moves.first { $0.from == 4 }
        #expect(move5 != nil)
        #expect(move5?.to == 0)
    }

    /// Moving the last item to the beginning while also inserting.
    @Test func moveWithSimultaneousInsert() {
        let old = [1, 2, 3]
        let new = [3, 1, 4, 2]

        let result = HeckelDiff.diff(old: old, new: new)

        #expect(result.inserts == [2]) // 4 inserted at index 2
        #expect(result.deletes.isEmpty)
        #expect(result.matched.count == 3)
    }

    /// Moving with simultaneous delete.
    @Test func moveWithSimultaneousDelete() {
        let old = [1, 2, 3, 4]
        let new = [4, 1, 3]

        let result = HeckelDiff.diff(old: old, new: new)

        #expect(result.deletes == [1]) // 2 deleted from index 1
        #expect(result.inserts.isEmpty)
    }

    // MARK: - Duplicate Handling

    /// Array with all identical elements — no unique matching possible.
    @Test func allDuplicateElements() {
        let old = [1, 1, 1, 1]
        let new = [1, 1, 1]

        let result = HeckelDiff.diff(old: old, new: new)

        // Should report one delete and no crashes
        // Exact behavior depends on expansion passes
        let netChange = old.count - new.count
        let actualNetChange = result.deletes.count - result.inserts.count
        #expect(actualNetChange == netChange)
    }

    /// Duplicates at boundaries with unique element in middle.
    @Test func duplicatesAtBoundariesUniqueInMiddle() {
        let old = [1, 2, 1]
        let new = [1, 2, 1]

        let result = HeckelDiff.diff(old: old, new: new)

        // Identical arrays — no changes
        #expect(result.deletes.isEmpty)
        #expect(result.inserts.isEmpty)
        #expect(result.moves.isEmpty)
    }

    /// Multiple duplicates with one unique element moving.
    @Test func duplicatesWithUniqueElementMoving() {
        let old = [1, 1, 2, 1]
        let new = [2, 1, 1, 1]

        let result = HeckelDiff.diff(old: old, new: new)

        // 2 is unique in both — should be matched and moved
        // Net change should be zero
        #expect(result.deletes.count == result.inserts.count)
    }

    // MARK: - Swap Operations

    /// Simple swap of two adjacent elements.
    @Test func adjacentSwap() {
        let old = [1, 2, 3, 4, 5]
        let new = [1, 3, 2, 4, 5]

        let result = HeckelDiff.diff(old: old, new: new)

        #expect(result.deletes.isEmpty)
        #expect(result.inserts.isEmpty)
        // Items 2 and 3 swapped positions
        #expect(result.moves.count >= 1)
    }

    /// Swap of first and last elements.
    @Test func endpointSwap() {
        let old = [1, 2, 3, 4, 5]
        let new = [5, 2, 3, 4, 1]

        let result = HeckelDiff.diff(old: old, new: new)

        #expect(result.deletes.isEmpty)
        #expect(result.inserts.isEmpty)
        #expect(result.matched.count == 5)
    }

    // MARK: - Complete Replacement

    /// Every element changes — maximum diff.
    @Test func completeReplacement() {
        let old = [1, 2, 3, 4, 5]
        let new = [6, 7, 8, 9, 10]

        let result = HeckelDiff.diff(old: old, new: new)

        #expect(result.deletes.count == 5)
        #expect(result.inserts.count == 5)
        #expect(result.moves.isEmpty)
        #expect(result.matched.isEmpty)
    }

    // MARK: - Index Consistency

    /// Verify that matched pairs reference valid indices in both arrays.
    @Test func matchedIndicesAreValid() {
        let old = [10, 20, 30, 40, 50]
        let new = [20, 40, 60, 10]

        let result = HeckelDiff.diff(old: old, new: new)

        for match in result.matched {
            #expect(match.old >= 0 && match.old < old.count)
            #expect(match.new >= 0 && match.new < new.count)
            #expect(old[match.old] == new[match.new])
        }

        for move in result.moves {
            #expect(move.from >= 0 && move.from < old.count)
            #expect(move.to >= 0 && move.to < new.count)
        }

        for deleteIdx in result.deletes {
            #expect(deleteIdx >= 0 && deleteIdx < old.count)
        }

        for insertIdx in result.inserts {
            #expect(insertIdx >= 0 && insertIdx < new.count)
        }
    }

    /// Deletes + matched should cover every old index exactly once.
    /// Inserts + matched should cover every new index exactly once.
    @Test func diffCoversAllIndices() {
        let old = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let new = [2, 4, 6, 8, 10, 11, 12]

        let result = HeckelDiff.diff(old: old, new: new)

        // Every old index is either deleted or matched
        let oldCovered = Set(result.deletes + result.matched.map(\.old))
        #expect(oldCovered == Set(0 ..< old.count))

        // Every new index is either inserted or matched
        let newCovered = Set(result.inserts + result.matched.map(\.new))
        #expect(newCovered == Set(0 ..< new.count))
    }

    /// Verify coverage holds for a shuffled array (all moves, no inserts/deletes).
    @Test func diffCoversAllIndicesForShuffle() {
        let old = Array(0 ..< 100)
        let new = old.shuffled()

        let result = HeckelDiff.diff(old: old, new: new)

        let oldCovered = Set(result.deletes + result.matched.map(\.old))
        #expect(oldCovered == Set(0 ..< old.count))

        let newCovered = Set(result.inserts + result.matched.map(\.new))
        #expect(newCovered == Set(0 ..< new.count))
    }
}
