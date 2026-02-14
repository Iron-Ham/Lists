// MARK: - HeckelDiff

/// Implementation of Paul Heckel's 6-pass O(n) diff algorithm for flat arrays.
enum HeckelDiff {
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
    var moves = [(from: Int, to: Int)]()
    moves.reserveCapacity(min(old.count, new.count))
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
        if oldIdx != newIdx {
          moves.append((from: oldIdx, to: newIdx))
        }
      }
    }

    return DiffResult(
      deletes: deletes,
      inserts: inserts,
      moves: moves,
      matched: matched
    )
  }
}
