/// A hierarchical snapshot representing the items within a single section.
///
/// Use a section snapshot to model parent–child relationships for outline-style lists.
/// Items can be expanded or collapsed, and the ``visibleItems`` property returns only
/// the items that are currently visible given the expansion state.
public struct DiffableDataSourceSectionSnapshot<ItemIdentifierType: Hashable & Sendable>: Sendable {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  /// All items in depth-first order, including collapsed items.
  public private(set) var items = [ItemIdentifierType]()

  /// The top-level items that have no parent.
  public var rootItems: [ItemIdentifierType] {
    items.filter { parentMap[$0] == nil }
  }

  /// The items that are currently visible given the expansion state of all ancestors.
  public var visibleItems: [ItemIdentifierType] {
    // Single-pass top-down: an item is visible iff it has no parent,
    // or its parent is both expanded and visible. We walk the flat list
    // (which is already in depth-first order) and track visibility per item.
    guard !items.isEmpty else { return [] }
    var visible = [ItemIdentifierType]()
    visible.reserveCapacity(items.count)
    var isVisibleMap = [ItemIdentifierType: Bool]()
    isVisibleMap.reserveCapacity(items.count)

    for item in items {
      guard let parent = parentMap[item] else {
        // Root item — always visible
        isVisibleMap[item] = true
        visible.append(item)
        continue
      }
      let parentVisible = isVisibleMap[parent] ?? false
      let parentExpanded = expandedItems.contains(parent)
      let itemVisible = parentVisible && parentExpanded
      isVisibleMap[item] = itemVisible
      if itemVisible {
        visible.append(item)
      }
    }
    return visible
  }

  /// Appends items as children of the given parent, or as root items if `parent` is `nil`.
  public mutating func append(_ items: [ItemIdentifierType], to parent: ItemIdentifierType? = nil) {
    if let parent {
      // Append as children of parent
      var children = childrenMap[parent] ?? []
      children.append(contentsOf: items)
      childrenMap[parent] = children

      for item in items {
        parentMap[item] = parent
      }

      // Insert in flat list after parent and its existing children
      guard let parentIndex = self.items.firstIndex(of: parent) else { return }

      // Find the last descendant of parent
      var insertIndex = parentIndex + 1
      while insertIndex < self.items.count {
        if isDescendant(self.items[insertIndex], of: parent) {
          insertIndex += 1
        } else {
          break
        }
      }

      self.items.insert(contentsOf: items, at: insertIndex)
    } else {
      // Append as root items
      self.items.append(contentsOf: items)
    }
    itemSet.formUnion(items)
  }

  /// Inserts items immediately before the specified item.
  public mutating func insert(_ items: [ItemIdentifierType], before item: ItemIdentifierType) {
    guard let index = self.items.firstIndex(of: item) else { return }

    self.items.insert(contentsOf: items, at: index)
    itemSet.formUnion(items)

    // Update parent/children maps if the reference item has a parent
    if let parent = parentMap[item] {
      for newItem in items {
        parentMap[newItem] = parent
      }

      if var siblings = childrenMap[parent], let siblingIndex = siblings.firstIndex(of: item) {
        siblings.insert(contentsOf: items, at: siblingIndex)
        childrenMap[parent] = siblings
      }
    }
  }

  /// Inserts items immediately after the specified item and its descendants.
  public mutating func insert(_ items: [ItemIdentifierType], after item: ItemIdentifierType) {
    guard let index = self.items.firstIndex(of: item) else { return }

    // Find the end of this item's descendants
    var insertIndex = index + 1
    while insertIndex < self.items.count {
      if isDescendant(self.items[insertIndex], of: item) {
        insertIndex += 1
      } else {
        break
      }
    }

    self.items.insert(contentsOf: items, at: insertIndex)
    itemSet.formUnion(items)

    // Update parent/children maps if the reference item has a parent
    if let parent = parentMap[item] {
      for newItem in items {
        parentMap[newItem] = parent
      }

      if var siblings = childrenMap[parent], let siblingIndex = siblings.firstIndex(of: item) {
        siblings.insert(contentsOf: items, at: siblingIndex + 1)
        childrenMap[parent] = siblings
      }
    }
  }

  /// Removes items and all their descendants from the snapshot.
  public mutating func delete(_ items: [ItemIdentifierType]) {
    // Collect all items to delete including descendants
    var toDelete = Set<ItemIdentifierType>(minimumCapacity: items.count)
    for item in items {
      toDelete.insert(item)
      collectDescendants(of: item, into: &toDelete)
    }

    // Single-pass removal from flat list
    self.items.removeAll { toDelete.contains($0) }
    itemSet.subtract(toDelete)

    // Clean up maps
    for item in toDelete {
      // Remove from parent's children list only if the parent survives
      if let parent = parentMap[item], !toDelete.contains(parent) {
        childrenMap[parent]?.removeAll { $0 == item }
      }
      parentMap.removeValue(forKey: item)
      childrenMap.removeValue(forKey: item)
      expandedItems.remove(item)
    }
  }

  /// Returns the parent of the specified item, or `nil` if it is a root item.
  public func parent(of item: ItemIdentifierType) -> ItemIdentifierType? {
    parentMap[item]
  }

  /// Returns a new section snapshot containing only the subtree rooted at the specified item.
  public func snapshot(of item: ItemIdentifierType, includingParent: Bool = false) -> DiffableDataSourceSectionSnapshot {
    var newSnapshot = DiffableDataSourceSectionSnapshot()

    if includingParent {
      newSnapshot.items.append(item)
      newSnapshot.itemSet.insert(item)
    }

    // Add all descendants
    addDescendants(of: item, to: &newSnapshot)

    // Copy relevant maps
    for snapshotItem in newSnapshot.items {
      if let parent = parentMap[snapshotItem] {
        newSnapshot.parentMap[snapshotItem] = parent
      }
      if let children = childrenMap[snapshotItem] {
        newSnapshot.childrenMap[snapshotItem] = children
      }
      if expandedItems.contains(snapshotItem) {
        newSnapshot.expandedItems.insert(snapshotItem)
      }
    }

    return newSnapshot
  }

  /// Returns whether the snapshot contains the specified item.
  public func contains(_ item: ItemIdentifierType) -> Bool {
    itemSet.contains(item)
  }

  /// Returns the nesting depth of the specified item (0 for root items).
  public func level(of item: ItemIdentifierType) -> Int {
    var level = 0
    var current = item
    while let parent = parentMap[current] {
      level += 1
      current = parent
    }
    return level
  }

  /// Returns whether the item is visible given the current expansion state of its ancestors.
  public func isVisible(_ item: ItemIdentifierType) -> Bool {
    var current = item
    while let parent = parentMap[current] {
      if !expandedItems.contains(parent) {
        return false
      }
      current = parent
    }
    return true
  }

  /// Returns whether the specified item is in the expanded state.
  public func isExpanded(_ item: ItemIdentifierType) -> Bool {
    expandedItems.contains(item)
  }

  /// Expands the specified items, making their children visible.
  public mutating func expand(_ items: [ItemIdentifierType]) {
    expandedItems.formUnion(items)
  }

  /// Collapses the specified items, hiding their children.
  public mutating func collapse(_ items: [ItemIdentifierType]) {
    expandedItems.subtract(items)
  }

  // MARK: Private

  private var itemSet = Set<ItemIdentifierType>()
  private var parentMap = [ItemIdentifierType: ItemIdentifierType]()
  private var childrenMap = [ItemIdentifierType: [ItemIdentifierType]]()
  private var expandedItems = Set<ItemIdentifierType>()

  private func collectDescendants(of item: ItemIdentifierType, into set: inout Set<ItemIdentifierType>) {
    guard let children = childrenMap[item] else { return }
    for child in children {
      set.insert(child)
      collectDescendants(of: child, into: &set)
    }
  }

  private func isDescendant(_ item: ItemIdentifierType, of ancestor: ItemIdentifierType) -> Bool {
    var current = item
    while let parent = parentMap[current] {
      if parent == ancestor {
        return true
      }
      current = parent
    }
    return false
  }

  private func addDescendants(of item: ItemIdentifierType, to snapshot: inout DiffableDataSourceSectionSnapshot) {
    guard let children = childrenMap[item] else { return }

    for child in children {
      snapshot.items.append(child)
      snapshot.itemSet.insert(child)
      addDescendants(of: child, to: &snapshot)
    }
  }
}
