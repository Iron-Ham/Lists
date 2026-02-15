// MARK: - HeckelDiff

/// Implementation of Paul Heckel's 6-pass O(n) diff algorithm for flat arrays.
enum HeckelDiff {

  // MARK: Internal

  /// Tracks occurrence count of a symbol.
  enum Counter {
    case zero
    case one(index: Int)
    case many

    mutating func increment(at index: Int) {
      switch self {
      case .zero:
        self = .one(index: index)
      case .one:
        self = .many
      case .many:
        break
      }
    }
  }

  /// Value type tracking symbol occurrences across old and new arrays.
  /// Stored in a contiguous array to avoid per-element heap allocations.
  struct SymbolEntry {
    var oldCounter = Counter.zero
    var newCounter = Counter.zero
  }

  /// Entry in the OA/NA arrays, tracking either an index into the symbol
  /// entries table or the matched index in the other array.
  enum ArrayEntry {
    case tableIndex(Int)
    case indexInOther(Int)
  }

  struct DiffResult: Sendable {
    let deletes: [Int]
    let inserts: [Int]
    let moves: [(from: Int, to: Int)]
    let matched: [(old: Int, new: Int)]
  }

  static func diff<T: Hashable>(old: [T], new: [T]) -> DiffResult {
    guard !old.isEmpty || !new.isEmpty else {
      return DiffResult(deletes: [], inserts: [], moves: [], matched: [])
    }

    var entries = ContiguousArray<SymbolEntry>()
    entries.reserveCapacity(old.count + new.count)
    var symbolTable = [T: Int]()
    symbolTable.reserveCapacity(old.count + new.count)
    var NA = ContiguousArray<ArrayEntry>()
    var OA = ContiguousArray<ArrayEntry>()

    // Pass 1: Scan new array
    NA.reserveCapacity(new.count)
    for (index, element) in new.enumerated() {
      let entryIdx: Int
      if let existing = symbolTable[element] {
        entryIdx = existing
      } else {
        entryIdx = entries.count
        entries.append(SymbolEntry())
        symbolTable[element] = entryIdx
      }
      entries[entryIdx].newCounter.increment(at: index)
      NA.append(.tableIndex(entryIdx))
    }

    // Pass 2: Scan old array
    OA.reserveCapacity(old.count)
    for (index, element) in old.enumerated() {
      let entryIdx: Int
      if let existing = symbolTable[element] {
        entryIdx = existing
      } else {
        entryIdx = entries.count
        entries.append(SymbolEntry())
        symbolTable[element] = entryIdx
      }
      entries[entryIdx].oldCounter.increment(at: index)
      OA.append(.tableIndex(entryIdx))
    }

    // Pass 3: Match uniques
    for newIdx in 0 ..< NA.count {
      if case .tableIndex(let eIdx) = NA[newIdx] {
        let entry = entries[eIdx]
        if
          case .one(let oldIdx) = entry.oldCounter,
          case .one(let checkedNewIdx) = entry.newCounter,
          checkedNewIdx == newIdx
        {
          NA[newIdx] = .indexInOther(oldIdx)
          OA[oldIdx] = .indexInOther(newIdx)
        }
      }
    }

    // Pass 4: Forward expansion
    for i in 0 ..< NA.count {
      if case .indexInOther(let j) = NA[i] {
        let nextI = i + 1
        let nextJ = j + 1
        if nextI < new.count, nextJ < old.count {
          if
            case .tableIndex = NA[nextI],
            case .tableIndex = OA[nextJ],
            new[nextI] == old[nextJ]
          {
            NA[nextI] = .indexInOther(nextJ)
            OA[nextJ] = .indexInOther(nextI)
          }
        }
      }
    }

    // Pass 5: Backward expansion
    for i in (0 ..< NA.count).reversed() {
      if case .indexInOther(let j) = NA[i] {
        let prevI = i - 1
        let prevJ = j - 1
        if prevI >= 0, prevJ >= 0 {
          if
            case .tableIndex = NA[prevI],
            case .tableIndex = OA[prevJ],
            new[prevI] == old[prevJ]
          {
            NA[prevI] = .indexInOther(prevJ)
            OA[prevJ] = .indexInOther(prevI)
          }
        }
      }
    }

    // Pass 6: Collect results
    var deletes = [Int]()
    deletes.reserveCapacity(old.count)
    var inserts = [Int]()
    inserts.reserveCapacity(new.count)
    var matched = [(old: Int, new: Int)]()
    matched.reserveCapacity(min(old.count, new.count))

    for (oldIdx, entry) in OA.enumerated() {
      if case .tableIndex = entry {
        deletes.append(oldIdx)
      }
    }

    for (newIdx, entry) in NA.enumerated() {
      switch entry {
      case .tableIndex:
        inserts.append(newIdx)
      case .indexInOther(let oldIdx):
        matched.append((old: oldIdx, new: newIdx))
      }
    }

    // Compute minimal moves using LIS.
    // Only elements whose relative order changed among surviving items need
    // explicit moves — positional shifts from deletes/inserts are handled
    // automatically by UICollectionView's batch update system.
    let moves = minimalMoves(from: matched)

    return DiffResult(
      deletes: deletes,
      inserts: inserts,
      moves: moves,
      matched: matched
    )
  }

  // MARK: Private

  /// Computes the minimal set of moves needed to reorder matched elements.
  ///
  /// Given matched pairs sorted by new index, finds the Longest Increasing
  /// Subsequence (LIS) of old indices. Elements in the LIS are already in
  /// correct relative order and don't need explicit moves. Elements outside
  /// the LIS must be moved to achieve the desired ordering.
  private static func minimalMoves(from matched: [(old: Int, new: Int)]) -> [(from: Int, to: Int)] {
    guard matched.count > 1 else { return [] }

    let oldIndices = matched.map(\.old)
    let stablePositions = lisPositions(oldIndices)

    var moves = [(from: Int, to: Int)]()
    for (pos, pair) in matched.enumerated() {
      if !stablePositions.contains(pos) {
        moves.append((from: pair.old, to: pair.new))
      }
    }
    return moves
  }

  /// Returns the set of positions in `values` that form a longest increasing
  /// subsequence, using patience-sorting in O(n log n) time.
  private static func lisPositions(_ values: [Int]) -> Set<Int> {
    let n = values.count
    guard n > 0 else { return [] }

    // tailIndices[i] = position in `values` whose value is the smallest tail
    // of any increasing subsequence of length i+1 found so far.
    var tailIndices = ContiguousArray<Int>()
    tailIndices.reserveCapacity(n)

    // predecessor[i] = position of the element before `values[i]` in its LIS chain.
    var predecessor = ContiguousArray<Int>(repeating: -1, count: n)

    for i in 0 ..< n {
      let val = values[i]

      // Binary search: find leftmost slot where the tail value >= val
      var lo = 0
      var hi = tailIndices.count
      while lo < hi {
        let mid = lo + (hi - lo) / 2
        if values[tailIndices[mid]] < val {
          lo = mid + 1
        } else {
          hi = mid
        }
      }

      if lo > 0 {
        predecessor[i] = tailIndices[lo - 1]
      }
      if lo == tailIndices.count {
        tailIndices.append(i)
      } else {
        tailIndices[lo] = i
      }
    }

    // Reconstruct: walk the predecessor chain from the last LIS element.
    var result = Set<Int>(minimumCapacity: tailIndices.count)
    var idx = tailIndices[tailIndices.count - 1]
    while idx >= 0 {
      result.insert(idx)
      idx = predecessor[idx]
    }
    return result
  }
}
