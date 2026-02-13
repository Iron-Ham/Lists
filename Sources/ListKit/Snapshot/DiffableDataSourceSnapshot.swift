public struct DiffableDataSourceSnapshot<SectionIdentifierType: Hashable & Sendable,
    ItemIdentifierType: Hashable & Sendable>: Sendable
{
    // MARK: - Internal Storage

    /// Ordered section identifiers.
    public private(set) var sectionIdentifiers: [SectionIdentifierType] = []

    /// Items per section, parallel to `sectionIdentifiers` (same index = same section).
    /// Replacing `[SectionID: [Item]]` with a flat array eliminates per-query hashing.
    private var sectionItemArrays: [[ItemIdentifierType]] = []

    /// Section identifier → position in `sectionIdentifiers` / `sectionItemArrays`.
    private var sectionIndex: [SectionIdentifierType: Int] = [:]

    /// Reverse lookup: item → section. Built lazily on first mutation that needs it.
    /// The critical path (build snapshot → diff) never touches this.
    private var _itemToSection: [ItemIdentifierType: SectionIdentifierType]?

    /// Total item count, updated incrementally on every mutation.
    public private(set) var numberOfItems: Int = 0

    public private(set) var reloadedItemIdentifiers: Set<ItemIdentifierType> = []
    public private(set) var reconfiguredItemIdentifiers: Set<ItemIdentifierType> = []
    public private(set) var reloadedSectionIdentifiers: Set<SectionIdentifierType> = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Lazy Reverse Index

    /// Builds the item→section reverse map from scratch. O(totalItems).
    /// Only called on first use by a mutation method that needs reverse lookup.
    private mutating func ensureItemToSection() {
        guard _itemToSection == nil else { return }
        var map = [ItemIdentifierType: SectionIdentifierType]()
        map.reserveCapacity(numberOfItems)
        for (idx, section) in sectionIdentifiers.enumerated() {
            for item in sectionItemArrays[idx] {
                map[item] = section
            }
        }
        _itemToSection = map
    }

    // MARK: - Section Operations

    public mutating func appendSections(_ identifiers: [SectionIdentifierType]) {
        sectionItemArrays.reserveCapacity(sectionItemArrays.count + identifiers.count)
        for identifier in identifiers {
            sectionIndex[identifier] = sectionIdentifiers.count
            sectionIdentifiers.append(identifier)
            sectionItemArrays.append([])
        }
    }

    public mutating func insertSections(_ identifiers: [SectionIdentifierType], beforeSection toIdentifier: SectionIdentifierType) {
        guard let index = sectionIndex[toIdentifier] else { return }
        sectionIdentifiers.insert(contentsOf: identifiers, at: index)
        for offset in 0 ..< identifiers.count {
            sectionItemArrays.insert([], at: index + offset)
        }
        rebuildSectionIndex()
    }

    public mutating func insertSections(_ identifiers: [SectionIdentifierType], afterSection toIdentifier: SectionIdentifierType) {
        guard let index = sectionIndex[toIdentifier] else { return }
        let insertAt = index + 1
        sectionIdentifiers.insert(contentsOf: identifiers, at: insertAt)
        for offset in 0 ..< identifiers.count {
            sectionItemArrays.insert([], at: insertAt + offset)
        }
        rebuildSectionIndex()
    }

    public mutating func deleteSections(_ identifiers: [SectionIdentifierType]) {
        let toDelete = Set(identifiers)
        var indicesToRemove: [Int] = []
        indicesToRemove.reserveCapacity(toDelete.count)
        // Deduplicate via the Set to avoid double-counting numberOfItems
        for identifier in toDelete {
            guard let idx = sectionIndex[identifier] else { continue }
            indicesToRemove.append(idx)
            let items = sectionItemArrays[idx]
            numberOfItems -= items.count
            if _itemToSection != nil {
                for item in items {
                    _itemToSection!.removeValue(forKey: item)
                }
            }
        }
        sectionIdentifiers.removeAll { toDelete.contains($0) }
        for idx in indicesToRemove.sorted().reversed() {
            sectionItemArrays.remove(at: idx)
        }
        rebuildSectionIndex()
    }

    public mutating func moveSection(_ identifier: SectionIdentifierType, beforeSection toIdentifier: SectionIdentifierType) {
        guard let fromIndex = sectionIndex[identifier],
              let toIndex = sectionIndex[toIdentifier] else { return }
        let items = sectionItemArrays.remove(at: fromIndex)
        sectionIdentifiers.remove(at: fromIndex)
        let newToIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
        sectionIdentifiers.insert(identifier, at: newToIndex)
        sectionItemArrays.insert(items, at: newToIndex)
        rebuildSectionIndex()
    }

    public mutating func moveSection(_ identifier: SectionIdentifierType, afterSection toIdentifier: SectionIdentifierType) {
        guard let fromIndex = sectionIndex[identifier],
              let toIndex = sectionIndex[toIdentifier] else { return }
        let items = sectionItemArrays.remove(at: fromIndex)
        sectionIdentifiers.remove(at: fromIndex)
        let newToIndex = fromIndex < toIndex ? toIndex : toIndex + 1
        sectionIdentifiers.insert(identifier, at: newToIndex)
        sectionItemArrays.insert(items, at: newToIndex)
        rebuildSectionIndex()
    }

    public mutating func reloadSections(_ identifiers: [SectionIdentifierType]) {
        reloadedSectionIdentifiers.formUnion(identifiers)
    }

    // MARK: - Item Operations

    public mutating func appendItems(_ identifiers: [ItemIdentifierType], toSection sectionIdentifier: SectionIdentifierType? = nil) {
        let targetSection = sectionIdentifier ?? sectionIdentifiers.last
        guard let section = targetSection, let idx = sectionIndex[section] else {
            preconditionFailure("No section available to append items")
        }

        // Validate no duplicate items — duplicates across sections corrupt changesets.
        // Uses reverse map for O(1) cross-section check when available;
        // always validates intra-batch duplicates.
        #if DEBUG
            if identifiers.count > 1 {
                var seen = Set<ItemIdentifierType>(minimumCapacity: identifiers.count)
                for identifier in identifiers {
                    assert(seen.insert(identifier).inserted,
                           "Duplicate item \(identifier) in appended batch")
                }
            }
            if let map = _itemToSection {
                for identifier in identifiers {
                    assert(map[identifier] == nil,
                           "Item \(identifier) already exists in another section. Each item must belong to exactly one section.")
                }
            }
        #endif

        sectionItemArrays[idx].append(contentsOf: identifiers)
        numberOfItems += identifiers.count

        // Only maintain reverse map if it was already built (by a prior mutation).
        // The common build-then-diff path skips this entirely.
        if _itemToSection != nil {
            for identifier in identifiers {
                _itemToSection![identifier] = section
            }
        }
    }

    public mutating func insertItems(_ identifiers: [ItemIdentifierType], beforeItem beforeIdentifier: ItemIdentifierType) {
        ensureItemToSection()
        guard let section = _itemToSection![beforeIdentifier],
              let sIdx = sectionIndex[section],
              let index = sectionItemArrays[sIdx].firstIndex(of: beforeIdentifier) else { return }

        sectionItemArrays[sIdx].insert(contentsOf: identifiers, at: index)
        for identifier in identifiers {
            _itemToSection![identifier] = section
        }
        numberOfItems += identifiers.count
    }

    public mutating func insertItems(_ identifiers: [ItemIdentifierType], afterItem afterIdentifier: ItemIdentifierType) {
        ensureItemToSection()
        guard let section = _itemToSection![afterIdentifier],
              let sIdx = sectionIndex[section],
              let index = sectionItemArrays[sIdx].firstIndex(of: afterIdentifier) else { return }

        sectionItemArrays[sIdx].insert(contentsOf: identifiers, at: index + 1)
        for identifier in identifiers {
            _itemToSection![identifier] = section
        }
        numberOfItems += identifiers.count
    }

    public mutating func deleteItems(_ identifiers: [ItemIdentifierType]) {
        let toDelete = Set(identifiers)
        var remaining = toDelete.count
        // Scan all section arrays directly — avoids building the reverse map.
        for sIdx in sectionItemArrays.indices {
            let before = sectionItemArrays[sIdx].count
            sectionItemArrays[sIdx].removeAll { toDelete.contains($0) }
            let removed = before - sectionItemArrays[sIdx].count
            numberOfItems -= removed
            remaining -= removed
            if remaining == 0 { break }
        }
        // Invalidate reverse map — it will rebuild lazily from the new state if needed.
        _itemToSection = nil
    }

    public mutating func deleteAllItems() {
        for idx in sectionItemArrays.indices {
            sectionItemArrays[idx] = []
        }
        _itemToSection = nil
        numberOfItems = 0
    }

    public mutating func moveItem(_ identifier: ItemIdentifierType, beforeItem toIdentifier: ItemIdentifierType) {
        ensureItemToSection()
        guard let fromSection = _itemToSection![identifier],
              let toSection = _itemToSection![toIdentifier],
              let fromSIdx = sectionIndex[fromSection],
              let toSIdx = sectionIndex[toSection] else { return }

        if let idx = sectionItemArrays[fromSIdx].firstIndex(of: identifier) {
            sectionItemArrays[fromSIdx].remove(at: idx)
        }

        guard let toIndex = sectionItemArrays[toSIdx].firstIndex(of: toIdentifier) else { return }
        sectionItemArrays[toSIdx].insert(identifier, at: toIndex)
        _itemToSection![identifier] = toSection
    }

    public mutating func moveItem(_ identifier: ItemIdentifierType, afterItem toIdentifier: ItemIdentifierType) {
        ensureItemToSection()
        guard let fromSection = _itemToSection![identifier],
              let toSection = _itemToSection![toIdentifier],
              let fromSIdx = sectionIndex[fromSection],
              let toSIdx = sectionIndex[toSection] else { return }

        if let idx = sectionItemArrays[fromSIdx].firstIndex(of: identifier) {
            sectionItemArrays[fromSIdx].remove(at: idx)
        }

        guard let toIndex = sectionItemArrays[toSIdx].firstIndex(of: toIdentifier) else { return }
        sectionItemArrays[toSIdx].insert(identifier, at: toIndex + 1)
        _itemToSection![identifier] = toSection
    }

    public mutating func reloadItems(_ identifiers: [ItemIdentifierType]) {
        reloadedItemIdentifiers.formUnion(identifiers)
    }

    public mutating func reconfigureItems(_ identifiers: [ItemIdentifierType]) {
        reconfiguredItemIdentifiers.formUnion(identifiers)
    }

    // MARK: - Queries

    public var numberOfSections: Int {
        sectionIdentifiers.count
    }

    public var itemIdentifiers: [ItemIdentifierType] {
        var result: [ItemIdentifierType] = []
        result.reserveCapacity(numberOfItems)
        for items in sectionItemArrays {
            result.append(contentsOf: items)
        }
        return result
    }

    public func itemIdentifiers(inSection identifier: SectionIdentifierType) -> [ItemIdentifierType] {
        guard let idx = sectionIndex[identifier] else { return [] }
        return sectionItemArrays[idx]
    }

    /// Fast path for data source queries — avoids section ID → index lookup.
    func itemIdentifier(inSectionAt sectionIndex: Int, itemIndex: Int) -> ItemIdentifierType? {
        guard sectionIndex < sectionItemArrays.count else { return nil }
        let items = sectionItemArrays[sectionIndex]
        guard itemIndex < items.count else { return nil }
        return items[itemIndex]
    }

    /// Fast path for data source queries — avoids section ID lookup.
    func numberOfItems(inSectionAt sectionIndex: Int) -> Int {
        guard sectionIndex < sectionItemArrays.count else { return 0 }
        return sectionItemArrays[sectionIndex].count
    }

    public func sectionIdentifier(containingItem identifier: ItemIdentifierType) -> SectionIdentifierType? {
        // Check the lazy map first (available if any mutation method was called).
        if let map = _itemToSection {
            return map[identifier]
        }
        // Otherwise linear scan — avoids forcing a build of the full reverse map
        // for a single query on a freshly-built snapshot.
        for (idx, items) in sectionItemArrays.enumerated() {
            if items.contains(identifier) {
                return sectionIdentifiers[idx]
            }
        }
        return nil
    }

    public func index(ofItem identifier: ItemIdentifierType) -> Int? {
        var currentIndex = 0
        for items in sectionItemArrays {
            if let localIndex = items.firstIndex(of: identifier) {
                return currentIndex + localIndex
            }
            currentIndex += items.count
        }
        return nil
    }

    public func index(ofSection identifier: SectionIdentifierType) -> Int? {
        sectionIndex[identifier]
    }

    public func numberOfItems(inSection identifier: SectionIdentifierType) -> Int {
        guard let idx = sectionIndex[identifier] else { return 0 }
        return sectionItemArrays[idx].count
    }

    // MARK: - Private Helpers

    private mutating func rebuildSectionIndex() {
        sectionIndex.removeAll(keepingCapacity: true)
        for (index, section) in sectionIdentifiers.enumerated() {
            sectionIndex[section] = index
        }
    }
}
