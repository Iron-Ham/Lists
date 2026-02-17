// ABOUTME: Value-type snapshot of sections and items, replacing NSDiffableDataSourceSnapshot.
// ABOUTME: Uses parallel arrays and lazy reverse indexes for O(1) lookups and O(n) diffing.

// MARK: - DiffableDataSourceSnapshot

/// A point-in-time representation of the data in a collection view, organized by sections and items.
///
/// `DiffableDataSourceSnapshot` is the primary currency type for updating a
/// ``CollectionViewDiffableDataSource``. Build a snapshot by appending sections and items,
/// then apply it to the data source to compute and animate the minimal set of changes.
///
/// Unlike Apple's `NSDiffableDataSourceSnapshot`, this implementation uses parallel arrays
/// and a lazy reverse index for O(1) section lookups and O(n) diffing without Foundation overhead.
public struct DiffableDataSourceSnapshot<
  SectionIdentifierType: Hashable & Sendable,
  ItemIdentifierType: Hashable & Sendable
>: Sendable {

  // MARK: Lifecycle

  public init() { }

  /// Creates a snapshot from an array of section–items pairs.
  ///
  /// This is a convenience initializer for building snapshots from pre-grouped data:
  /// ```swift
  /// let snapshot = DiffableDataSourceSnapshot(sections: [
  ///     ("favorites", [item1, item2]),
  ///     ("recent", [item3]),
  /// ])
  /// ```
  public init(sections: [(SectionIdentifierType, [ItemIdentifierType])]) {
    appendSections(sections.map(\.0))
    for (section, items) in sections {
      appendItems(items, toSection: section)
    }
  }

  // MARK: Public

  /// Ordered section identifiers.
  public private(set) var sectionIdentifiers = [SectionIdentifierType]()

  /// Total item count, updated incrementally on every mutation.
  /// The total number of items across all sections, updated incrementally on every mutation.
  public private(set) var numberOfItems = 0

  /// Items that have been marked for reload via ``reloadItems(_:)``.
  public private(set) var reloadedItemIdentifiers = Set<ItemIdentifierType>()
  /// Items that have been marked for reconfiguration via ``reconfigureItems(_:)``.
  public private(set) var reconfiguredItemIdentifiers = Set<ItemIdentifierType>()
  /// Sections that have been marked for reload via ``reloadSections(_:)``.
  public private(set) var reloadedSectionIdentifiers = Set<SectionIdentifierType>()

  /// Whether the snapshot contains no sections and no items.
  public var isEmpty: Bool {
    numberOfItems == 0 && sectionIdentifiers.isEmpty
  }

  /// The number of sections in the snapshot.
  public var numberOfSections: Int {
    sectionIdentifiers.count
  }

  /// All item identifiers across all sections, in order.
  public var itemIdentifiers: [ItemIdentifierType] {
    var result = [ItemIdentifierType]()
    result.reserveCapacity(numberOfItems)
    for items in sectionItemArrays {
      result.append(contentsOf: items)
    }
    return result
  }

  /// Appends the given section identifiers to the end of the snapshot.
  public mutating func appendSections(_ identifiers: [SectionIdentifierType]) {
    sectionItemArrays.reserveCapacity(sectionItemArrays.count + identifiers.count)
    for identifier in identifiers {
      sectionIndex[identifier] = sectionIdentifiers.count
      sectionIdentifiers.append(identifier)
      sectionItemArrays.append([])
    }
  }

  /// Inserts the given sections immediately before the specified section.
  public mutating func insertSections(_ identifiers: [SectionIdentifierType], beforeSection toIdentifier: SectionIdentifierType) {
    guard let index = sectionIndex[toIdentifier] else { return }
    sectionIdentifiers.insert(contentsOf: identifiers, at: index)
    for offset in 0 ..< identifiers.count {
      sectionItemArrays.insert([], at: index + offset)
    }
    rebuildSectionIndex()
  }

  /// Inserts the given sections immediately after the specified section.
  public mutating func insertSections(_ identifiers: [SectionIdentifierType], afterSection toIdentifier: SectionIdentifierType) {
    guard let index = sectionIndex[toIdentifier] else { return }
    let insertAt = index + 1
    sectionIdentifiers.insert(contentsOf: identifiers, at: insertAt)
    for offset in 0 ..< identifiers.count {
      sectionItemArrays.insert([], at: insertAt + offset)
    }
    rebuildSectionIndex()
  }

  /// Removes the specified sections and all their items from the snapshot.
  public mutating func deleteSections(_ identifiers: [SectionIdentifierType]) {
    let toDelete = Set(identifiers)
    var indicesToRemove = [Int]()
    indicesToRemove.reserveCapacity(toDelete.count)
    reloadedSectionIdentifiers.subtract(toDelete)
    // Deduplicate via the Set to avoid double-counting numberOfItems
    for identifier in toDelete {
      guard let idx = sectionIndex[identifier] else { continue }
      indicesToRemove.append(idx)
      let items = sectionItemArrays[idx]
      numberOfItems -= items.count
      for item in items {
        _itemToSection?.removeValue(forKey: item)
        reloadedItemIdentifiers.remove(item)
        reconfiguredItemIdentifiers.remove(item)
      }
    }
    sectionIdentifiers.removeAll { toDelete.contains($0) }
    for idx in indicesToRemove.sorted().reversed() {
      sectionItemArrays.remove(at: idx)
    }
    rebuildSectionIndex()
  }

  /// Moves the specified section to the position immediately before another section.
  public mutating func moveSection(_ identifier: SectionIdentifierType, beforeSection toIdentifier: SectionIdentifierType) {
    guard
      let fromIndex = sectionIndex[identifier],
      let toIndex = sectionIndex[toIdentifier]
    else { return }
    let items = sectionItemArrays.remove(at: fromIndex)
    sectionIdentifiers.remove(at: fromIndex)
    let newToIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
    sectionIdentifiers.insert(identifier, at: newToIndex)
    sectionItemArrays.insert(items, at: newToIndex)
    rebuildSectionIndex()
  }

  /// Moves the specified section to the position immediately after another section.
  public mutating func moveSection(_ identifier: SectionIdentifierType, afterSection toIdentifier: SectionIdentifierType) {
    guard
      let fromIndex = sectionIndex[identifier],
      let toIndex = sectionIndex[toIdentifier]
    else { return }
    let items = sectionItemArrays.remove(at: fromIndex)
    sectionIdentifiers.remove(at: fromIndex)
    let newToIndex = fromIndex < toIndex ? toIndex : toIndex + 1
    sectionIdentifiers.insert(identifier, at: newToIndex)
    sectionItemArrays.insert(items, at: newToIndex)
    rebuildSectionIndex()
  }

  /// Marks the specified sections for reload on the next apply.
  public mutating func reloadSections(_ identifiers: [SectionIdentifierType]) {
    reloadedSectionIdentifiers.formUnion(identifiers)
  }

  /// Appends items to the specified section, or to the last section if none is given.
  public mutating func appendItems(
    _ identifiers: [ItemIdentifierType],
    toSection sectionIdentifier: SectionIdentifierType? = nil
  ) {
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
        assert(
          seen.insert(identifier).inserted,
          "Duplicate item \(identifier) in appended batch"
        )
      }
    }
    if let map = _itemToSection {
      for identifier in identifiers {
        assert(
          map[identifier] == nil,
          "Item \(identifier) already exists in another section. Each item must belong to exactly one section."
        )
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

  /// Inserts items immediately before the specified item.
  public mutating func insertItems(_ identifiers: [ItemIdentifierType], beforeItem beforeIdentifier: ItemIdentifierType) {
    ensureItemToSection()
    guard
      let section = _itemToSection![beforeIdentifier],
      let sIdx = sectionIndex[section],
      let index = sectionItemArrays[sIdx].firstIndex(of: beforeIdentifier)
    else { return }

    sectionItemArrays[sIdx].insert(contentsOf: identifiers, at: index)
    for identifier in identifiers {
      _itemToSection![identifier] = section
    }
    numberOfItems += identifiers.count
  }

  /// Inserts items immediately after the specified item.
  public mutating func insertItems(_ identifiers: [ItemIdentifierType], afterItem afterIdentifier: ItemIdentifierType) {
    ensureItemToSection()
    guard
      let section = _itemToSection![afterIdentifier],
      let sIdx = sectionIndex[section],
      let index = sectionItemArrays[sIdx].firstIndex(of: afterIdentifier)
    else { return }

    sectionItemArrays[sIdx].insert(contentsOf: identifiers, at: index + 1)
    for identifier in identifiers {
      _itemToSection![identifier] = section
    }
    numberOfItems += identifiers.count
  }

  /// Removes the specified items from the snapshot.
  public mutating func deleteItems(_ identifiers: [ItemIdentifierType]) {
    let toDelete = Set(identifiers)
    reloadedItemIdentifiers.subtract(toDelete)
    reconfiguredItemIdentifiers.subtract(toDelete)

    if let map = _itemToSection {
      // Fast path: reverse map is available — only touch affected sections.
      var affectedSections = Set<Int>()
      for item in toDelete {
        if let section = map[item], let sIdx = sectionIndex[section] {
          affectedSections.insert(sIdx)
        }
        _itemToSection!.removeValue(forKey: item)
      }
      for sIdx in affectedSections {
        let before = sectionItemArrays[sIdx].count
        sectionItemArrays[sIdx].removeAll { toDelete.contains($0) }
        numberOfItems -= before - sectionItemArrays[sIdx].count
      }
    } else {
      // No reverse map — linear scan with early exit.
      var remaining = toDelete.count
      for sIdx in sectionItemArrays.indices {
        let before = sectionItemArrays[sIdx].count
        sectionItemArrays[sIdx].removeAll { toDelete.contains($0) }
        let removed = before - sectionItemArrays[sIdx].count
        numberOfItems -= removed
        remaining -= removed
        if remaining == 0 { break }
      }
    }
  }

  /// Removes all items from every section, leaving the section structure intact.
  public mutating func deleteAllItems() {
    for idx in sectionItemArrays.indices {
      sectionItemArrays[idx] = []
    }
    _itemToSection = nil
    numberOfItems = 0
    reloadedItemIdentifiers.removeAll()
    reconfiguredItemIdentifiers.removeAll()
  }

  /// Moves an item to the position immediately before another item.
  public mutating func moveItem(_ identifier: ItemIdentifierType, beforeItem toIdentifier: ItemIdentifierType) {
    ensureItemToSection()
    guard
      let fromSection = _itemToSection![identifier],
      let toSection = _itemToSection![toIdentifier],
      let fromSIdx = sectionIndex[fromSection],
      let toSIdx = sectionIndex[toSection]
    else { return }

    if let idx = sectionItemArrays[fromSIdx].firstIndex(of: identifier) {
      sectionItemArrays[fromSIdx].remove(at: idx)
    }

    guard let toIndex = sectionItemArrays[toSIdx].firstIndex(of: toIdentifier) else { return }
    sectionItemArrays[toSIdx].insert(identifier, at: toIndex)
    _itemToSection![identifier] = toSection
  }

  /// Moves an item to the position immediately after another item.
  public mutating func moveItem(_ identifier: ItemIdentifierType, afterItem toIdentifier: ItemIdentifierType) {
    ensureItemToSection()
    guard
      let fromSection = _itemToSection![identifier],
      let toSection = _itemToSection![toIdentifier],
      let fromSIdx = sectionIndex[fromSection],
      let toSIdx = sectionIndex[toSection]
    else { return }

    if let idx = sectionItemArrays[fromSIdx].firstIndex(of: identifier) {
      sectionItemArrays[fromSIdx].remove(at: idx)
    }

    guard let toIndex = sectionItemArrays[toSIdx].firstIndex(of: toIdentifier) else { return }
    sectionItemArrays[toSIdx].insert(identifier, at: toIndex + 1)
    _itemToSection![identifier] = toSection
  }

  /// Marks items for reload, causing their cells to be dequeued and configured again on the next apply.
  public mutating func reloadItems(_ identifiers: [ItemIdentifierType]) {
    reloadedItemIdentifiers.formUnion(identifiers)
  }

  /// Marks items for reconfiguration, updating existing cells in place without dequeuing.
  public mutating func reconfigureItems(_ identifiers: [ItemIdentifierType]) {
    reconfiguredItemIdentifiers.formUnion(identifiers)
  }

  /// Returns the item identifiers in the specified section.
  public func itemIdentifiers(inSection identifier: SectionIdentifierType) -> [ItemIdentifierType] {
    guard let idx = sectionIndex[identifier] else { return [] }
    return sectionItemArrays[idx]
  }

  /// Returns the section that contains the specified item, or `nil` if not found.
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

  /// Returns the global index of the specified item across all sections, or `nil` if not found.
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

  /// Returns the index of the specified section, or `nil` if not found.
  public func index(ofSection identifier: SectionIdentifierType) -> Int? {
    sectionIndex[identifier]
  }

  /// Returns the number of items in the specified section.
  public func numberOfItems(inSection identifier: SectionIdentifierType) -> Int {
    guard let idx = sectionIndex[identifier] else { return 0 }
    return sectionItemArrays[idx].count
  }

  /// Returns whether the snapshot contains the specified item.
  public func contains(_ identifier: ItemIdentifierType) -> Bool {
    if let map = _itemToSection {
      return map[identifier] != nil
    }
    return sectionItemArrays.contains { $0.contains(identifier) }
  }

  /// Returns whether the snapshot contains the specified section.
  public func contains(section identifier: SectionIdentifierType) -> Bool {
    sectionIndex[identifier] != nil
  }

  /// Returns the section identifier at the given index, or `nil` if out of bounds.
  public func sectionIdentifier(at index: Int) -> SectionIdentifierType? {
    guard index >= 0, index < sectionIdentifiers.count else { return nil }
    return sectionIdentifiers[index]
  }

  /// Replaces all items in the specified section with the given items.
  ///
  /// This is more efficient than deleting and re-appending when you want to replace
  /// a section's contents wholesale while keeping the section itself in place.
  public mutating func replaceItems(in section: SectionIdentifierType, with newItems: [ItemIdentifierType]) {
    guard let idx = sectionIndex[section] else {
      assertionFailure("Section \(section) not found in snapshot")
      return
    }

    #if DEBUG
    if newItems.count > 1 {
      var seen = Set<ItemIdentifierType>(minimumCapacity: newItems.count)
      for item in newItems {
        assert(seen.insert(item).inserted, "Duplicate item \(item) in replacement batch")
      }
    }
    if let map = _itemToSection {
      for item in newItems {
        assert(
          map[item] == nil || map[item] == section,
          "Item \(item) already exists in another section. Each item must belong to exactly one section."
        )
      }
    }
    #endif

    let oldItems = sectionItemArrays[idx]
    numberOfItems -= oldItems.count

    if _itemToSection != nil {
      for item in oldItems {
        _itemToSection!.removeValue(forKey: item)
      }
      for item in newItems {
        _itemToSection![item] = section
      }
    }

    // Clean reload/reconfigure markers for removed items
    for item in oldItems {
      reloadedItemIdentifiers.remove(item)
      reconfiguredItemIdentifiers.remove(item)
    }

    sectionItemArrays[idx] = newItems
    numberOfItems += newItems.count
  }

  /// Removes all items matching the predicate from every section.
  ///
  /// Items for which the predicate returns `true` are removed; others are kept.
  /// This follows the same convention as `removeAll(where:)` in the standard library.
  public mutating func removeItems(where isExcluded: (ItemIdentifierType) -> Bool) {
    for idx in sectionItemArrays.indices {
      let before = sectionItemArrays[idx].count
      sectionItemArrays[idx].removeAll { item in
        let shouldRemove = isExcluded(item)
        if shouldRemove {
          _itemToSection?.removeValue(forKey: item)
          reloadedItemIdentifiers.remove(item)
          reconfiguredItemIdentifiers.remove(item)
        }
        return shouldRemove
      }
      numberOfItems -= before - sectionItemArrays[idx].count
    }
  }

  // MARK: Internal

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

  // MARK: Private

  /// Items per section, parallel to `sectionIdentifiers` (same index = same section).
  /// Replacing `[SectionID: [Item]]` with a flat array eliminates per-query hashing.
  private var sectionItemArrays = [[ItemIdentifierType]]()

  /// Section identifier → position in `sectionIdentifiers` / `sectionItemArrays`.
  private var sectionIndex = [SectionIdentifierType: Int]()

  /// Reverse lookup: item → section. Built lazily on first mutation that needs it.
  /// The critical path (build snapshot → diff) never touches this.
  private var _itemToSection: [ItemIdentifierType: SectionIdentifierType]?

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

  private mutating func rebuildSectionIndex() {
    sectionIndex.removeAll(keepingCapacity: true)
    for (index, section) in sectionIdentifiers.enumerated() {
      sectionIndex[section] = index
    }
  }
}

// MARK: Equatable

/// Structural equality: two snapshots are equal when they have the same sections in the same
/// order with the same items in the same order. Transient markers (reload/reconfigure sets) are
/// intentionally excluded — they represent pending UI operations, not structural identity.
extension DiffableDataSourceSnapshot: Equatable {
  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.sectionIdentifiers == rhs.sectionIdentifiers
      && lhs.sectionItemArrays == rhs.sectionItemArrays
  }
}
